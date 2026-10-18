// The weekly project review: how often projects are reviewed, marking one reviewed, and dropping a project. In
// their own file (SwiftLint file_length) rather than suppressed.
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
    of projectID: TaskID,
    to interval: ReviewInterval?,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    _ = try activeProject(projectID, in: state)
    let interval = interval.map { ReviewInterval(days: $0.days) }
    guard state.reviewOverride(of: projectID) != interval else { return [] }
    let set = ReviewIntervalSet(taskID: projectID, interval: interval)
    return [envelope(EventID(ids.next()), .reviewIntervalSet(set), log: log)]
  }

  /// Marks the open project `projectID` reviewed on `date`, which is today. A project that was dropped is
  /// refused. Reviewing a project on the day it was last reviewed writes nothing.
  public func reviewProject(_ projectID: TaskID, on date: CalendarDate, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let state = LibraryState.replay(log)
    _ = try activeProject(projectID, in: state)
    guard state.lastReviewDate(of: projectID) != date else { return [] }
    let reviewed = TaskReviewed(taskID: projectID, date: date)
    return [envelope(EventID(ids.next()), .taskReviewed(reviewed), log: log)]
  }

  /// Gives up the open project `projectID` with every task and project open in it. Reopening it brings them
  /// all back.
  public func dropProject(_ projectID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    _ = try activeProject(projectID, in: LibraryState.replay(log))
    return [envelope(EventID(ids.next()), .taskDropped(TaskDropped(taskID: projectID)), log: log)]
  }
}
