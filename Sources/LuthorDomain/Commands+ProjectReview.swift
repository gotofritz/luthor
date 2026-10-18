// The weekly project review: how often projects are reviewed, marking one reviewed, and putting a project on
// hold, resuming it or dropping it. In their own file (SwiftLint file_length) rather than suppressed.
extension Commands {
  /// Sets how often projects without an interval of their own are reviewed; off turns review off for all of
  /// them. No days, or fewer, is off. Setting the interval it has writes nothing.
  public func setReviewDefault(_ interval: ReviewInterval, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let interval = ReviewInterval(days: interval.days)
    guard LibraryState.replay(log).defaultReviewInterval != interval else { return [] }
    return [envelope(EventID(ids.next()), .reviewDefaultSet(ReviewDefaultSet(interval: interval)), log: log)]
  }

  /// Sets how often the active project `projectID` is reviewed, in place of the default; off leaves it out of
  /// the review, and `nil` clears its own interval, so the default applies again. Setting the interval it has
  /// writes nothing.
  public func setReviewInterval(
    of projectID: ProjectID,
    to interval: ReviewInterval?,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    _ = try activeProject(projectID, in: state)
    let interval = interval.map { ReviewInterval(days: $0.days) }
    guard state.reviewOverride(of: projectID) != interval else { return [] }
    let set = ProjectReviewIntervalSet(projectID: projectID, interval: interval)
    return [envelope(EventID(ids.next()), .projectReviewIntervalSet(set), log: log)]
  }

  /// Marks the active project `projectID` reviewed on `date`, which is today. A project that was dropped is
  /// refused. Reviewing a project on the day it was last reviewed writes nothing.
  public func reviewProject(_ projectID: ProjectID, on date: CalendarDate, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let state = LibraryState.replay(log)
    let project = try activeProject(projectID, in: state)
    guard project.status != .dropped else { throw .projectDropped(projectID) }
    guard state.lastReviewDate(of: projectID) != date else { return [] }
    let reviewed = ProjectReviewed(projectID: projectID, date: date)
    return [envelope(EventID(ids.next()), .projectReviewed(reviewed), log: log)]
  }

  /// Puts the active project `projectID` on hold. Putting a project on hold that is on hold writes nothing.
  public func putOnHold(_ projectID: ProjectID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    try changeStatus(of: projectID, to: .onHold, log: log)
  }

  /// Brings the active project `projectID` back to work from on hold, or from dropped. Resuming a project that
  /// is not on hold or dropped writes nothing.
  public func resume(_ projectID: ProjectID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    try changeStatus(of: projectID, to: .active, log: log)
  }

  /// Gives up the active project `projectID`; its tasks stay open. Dropping a project that was dropped writes
  /// nothing.
  public func dropProject(_ projectID: ProjectID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    try changeStatus(of: projectID, to: .dropped, log: log)
  }

  private func changeStatus(
    of projectID: ProjectID,
    to status: ProjectStatus,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let project = try activeProject(projectID, in: LibraryState.replay(log))
    guard project.status != status else { return [] }
    let payload: EventPayload =
      switch status {
      case .active: .projectResumed(ProjectResumed(projectID: projectID))
      case .onHold: .projectPutOnHold(ProjectPutOnHold(projectID: projectID))
      case .dropped: .projectDropped(ProjectDropped(projectID: projectID))
      }
    return [envelope(EventID(ids.next()), payload, log: log)]
  }
}
