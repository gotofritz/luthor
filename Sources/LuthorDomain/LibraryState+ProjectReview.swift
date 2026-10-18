/// A project whose review is due, with the day it fell due.
public struct ProjectReviewItem: Equatable, Sendable {
  public let project: Project
  /// The day the review fell due; today or earlier.
  public let nextReview: CalendarDate

  public init(project: Project, nextReview: CalendarDate) {
    self.project = project
    self.nextReview = nextReview
  }
}

/// What the weekly project review is made of, kept apart from the rest of the state.
struct ProjectReviewRecords: Equatable, Sendable {
  /// How often a project without an interval of its own is reviewed.
  var defaultInterval = ReviewInterval.weekly
  /// The interval of the projects that have one of their own, which may be off.
  var intervals: [ProjectID: ReviewInterval] = [:]
  /// The day each project was last reviewed.
  var reviewedOn: [ProjectID: CalendarDate] = [:]
}

// The weekly project review: how the events change the state, and the pure functions that turn it into the
// next review of a project and the list of reviews that are due. In its own file (SwiftLint file_length)
// rather than suppressed.
extension LibraryState {
  /// Applies the events that set review intervals, mark a project reviewed, and drop a project; any other
  /// event changes nothing. An event for a project that is not active is ignored.
  mutating func applyProjectReview(_ payload: EventPayload) {
    switch payload {
    case .reviewDefaultSet(let set):
      projectReviews.defaultInterval = ReviewInterval(days: set.interval.days)
    case .projectReviewIntervalSet(let set):
      guard isActive(set.projectID) else { return }
      projectReviews.intervals[set.projectID] = set.interval.map { ReviewInterval(days: $0.days) }
    case .projectReviewed(let reviewed):
      guard let project = projects.first(where: { $0.id == reviewed.projectID }), project.status != .dropped else {
        return
      }
      projectReviews.reviewedOn[reviewed.projectID] = reviewed.date
    case .projectDropped(let dropped):
      updateProject(dropped.projectID) { $0.status = .dropped }
    default:
      break
    }
  }

  private func isActive(_ projectID: ProjectID) -> Bool {
    projects.contains { $0.id == projectID }
  }

  /// How often projects without an interval of their own are reviewed.
  public var defaultReviewInterval: ReviewInterval {
    projectReviews.defaultInterval
  }

  /// The interval the project is reviewed at: its own, else the default.
  public func reviewInterval(of projectID: ProjectID) -> ReviewInterval {
    projectReviews.intervals[projectID] ?? projectReviews.defaultInterval
  }

  /// The interval the project has of its own; `nil` while it follows the default.
  public func reviewOverride(of projectID: ProjectID) -> ReviewInterval? {
    projectReviews.intervals[projectID]
  }

  /// The day the project was last reviewed; `nil` while it never was.
  public func lastReviewDate(of projectID: ProjectID) -> CalendarDate? {
    projectReviews.reviewedOn[projectID]
  }

  /// The day the project is to be reviewed next: one interval after the day it was last reviewed, or created.
  /// A project created before the day was kept counts from 1970-01-01, so it is due at once. `nil` for a
  /// project that is not active, that was dropped, or whose review is off.
  public func nextReviewDate(of projectID: ProjectID) -> CalendarDate? {
    guard let project = projects.first(where: { $0.id == projectID }), project.status != .dropped,
      let days = reviewInterval(of: projectID).days
    else { return nil }
    let since = projectReviews.reviewedOn[projectID] ?? project.createdOn ?? CalendarDate(daysSinceEpoch: 0)
    return since.adding(days: days)
  }

  /// The view's projects whose next review is `today` or has passed, the longest overdue first and, within a
  /// day, in the order the projects were created.
  public func projectsDueForReview(in viewID: ViewID, today: CalendarDate) -> [ProjectReviewItem] {
    let due = view(viewID).projects.enumerated().compactMap { (position, project) -> (Int, ProjectReviewItem)? in
      guard let next = nextReviewDate(of: project.id), next <= today else { return nil }
      return (position, ProjectReviewItem(project: project, nextReview: next))
    }
    return due.sorted { ($0.1.nextReview, $0.0) < ($1.1.nextReview, $1.0) }.map { $0.1 }
  }
}
