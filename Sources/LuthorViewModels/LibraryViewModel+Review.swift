import LuthorDomain

// The daily review: logging the time a day took, closing its review, and the history of estimates. In its
// own file (SwiftLint file_length) rather than suppressed.
extension LibraryViewModel {
  /// Sets the minutes spent on a task on the day shown, or with `nil` clears them. A task that does not
  /// exist changes nothing.
  public func logTime(_ taskID: TaskID, minutes: Int?) {
    let day = planDate
    perform { (log) throws(CommandError) in
      try commands.logTime(taskID: taskID, on: day, minutes: minutes, log: log)
    }
  }

  /// Sets the minutes the current view spent on the day shown on work that was not in the plan, or with
  /// `nil` clears them.
  public func logUnplannedTime(minutes: Int?) {
    let viewID = currentView
    let day = planDate
    perform { (log) throws(CommandError) in
      try commands.logUnplannedTime(minutes, for: viewID, on: day, log: log)
    }
  }

  /// Closes the review of the day shown with a one-line note. A blank note reviews the day with none. A task
  /// that was done and estimated, with no time logged, is logged at its length now: the review's prefill.
  public func reviewDay(note: String) {
    let viewID = currentView
    let day = planDate
    let unlogged = state.dayReview(for: viewID, on: day, today: today).done.filter {
      $0.loggedMinutes == nil && $0.task.estimate != nil
    }
    perform { (log) throws(CommandError) in
      var events: [EventEnvelope] = []
      for entry in unlogged {
        events += try commands.logTime(taskID: entry.task.id, on: day, minutes: entry.currentMinutes, log: log + events)
      }
      return events + (try commands.reviewDay(of: viewID, on: day, note: note, log: log + events))
    }
  }

  /// What a task was estimated and how long it took; `nil` until it has both.
  public func estimateHistory(ofTask taskID: TaskID) -> EstimateHistory? {
    state.estimateHistory(ofTask: taskID)
  }

  /// What the tasks of a project were estimated and how long they took; `nil` until one has both.
  public func estimateHistory(ofProject projectID: TaskID) -> EstimateHistory? {
    state.estimateHistory(ofProject: projectID)
  }
}
