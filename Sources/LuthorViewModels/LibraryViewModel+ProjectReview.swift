import LuthorDomain

// The weekly project review: the list of projects due, marking one reviewed, how often projects are reviewed,
// and dropping a project. In its own file (SwiftLint file_length) rather than suppressed.
extension LibraryViewModel {
  /// Picks a project of the weekly review, whose tasks the next column lists, with no task selected.
  public func showReviewProject(_ projectID: ProjectID?) {
    reviewProjectID = projectID
    selection = nil
    editingCard = nil
    present()
  }

  /// Marks the picked project reviewed today and picks the one that takes its place in the list. With no
  /// project picked it changes nothing.
  public func markProjectReviewed() {
    guard let projectID = reviewProjectID else { return }
    let position = projectReview.firstIndex { $0.project.id == projectID } ?? 0
    let day = clock()
    perform { (log) throws(CommandError) in try commands.reviewProject(projectID, on: day, log: log) }
    showReviewProject(projectReview.isEmpty ? nil : projectReview[min(position, projectReview.count - 1)].project.id)
  }

  /// Sets how often projects without an interval of their own are reviewed; off turns review off for all.
  public func setReviewDefault(_ interval: ReviewInterval) {
    perform { (log) throws(CommandError) in try commands.setReviewDefault(interval, log: log) }
  }

  /// Sets how often one project is reviewed, in place of the default; off leaves it out of the review, and
  /// `nil` clears its own interval.
  public func setReviewInterval(of projectID: ProjectID, to interval: ReviewInterval?) {
    perform { (log) throws(CommandError) in try commands.setReviewInterval(of: projectID, to: interval, log: log) }
  }

  /// How often the project is reviewed: its own interval, else the default.
  public func reviewInterval(of projectID: ProjectID) -> ReviewInterval {
    state.reviewInterval(of: projectID)
  }

  /// The interval the project has of its own; `nil` while it follows the default.
  public func reviewOverride(of projectID: ProjectID) -> ReviewInterval? {
    state.reviewOverride(of: projectID)
  }

  /// The day the project is reviewed next; `nil` when its review is off or it was dropped.
  public func nextReviewDate(of projectID: ProjectID) -> CalendarDate? {
    state.nextReviewDate(of: projectID)
  }

  /// Gives up a project; it is not reviewed, and its tasks stay open.
  public func dropProject(_ projectID: ProjectID) {
    perform { (log) throws(CommandError) in try commands.dropProject(projectID, log: log) }
  }

  /// The project new tasks are captured into: the one the weekly review has picked, else the project shown,
  /// else none, which is the inbox.
  var captureProjectID: ProjectID? {
    section == .weeklyReview ? reviewProjectID : shownProjectID
  }

  /// Fills the list of projects due, and keeps one picked while the weekly review is shown: the project
  /// picked before if it is still due, else the first.
  func presentProjectReview() {
    reviewDefault = state.defaultReviewInterval
    projectReview = state.projectsDueForReview(in: currentView, today: today)
    if let picked = reviewProjectID, !projectReview.contains(where: { $0.project.id == picked }) {
      reviewProjectID = nil
    }
    if section == .weeklyReview, reviewProjectID == nil {
      reviewProjectID = projectReview.first?.project.id
    }
  }
}
