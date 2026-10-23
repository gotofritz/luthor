import LuthorDomain

// Repeating tasks: giving a task a rule, skipping one occurrence, and stopping the series. Completing a task that
// repeats makes the next one in `complete(_:)`. In its own file (SwiftLint file_length) rather than suppressed.
extension LibraryViewModel {
  /// How a task repeats; `nil` if it does not.
  public func repeatRule(of taskID: TaskID) -> RepeatRule? {
    _ = revision
    return state.repeatRule(of: taskID)
  }

  /// Makes a task repeat by `rule`, or with `nil` stops it. A repeat never gives the task a due date, and one
  /// with no due date is counted from the day the task is done.
  public func setRepeat(_ taskID: TaskID, to rule: RepeatRule?) {
    perform { (log) throws(CommandError) in
      let hasDue = LibraryState.replay(log).dueDate(of: taskID) != nil
      let rule = hasDue ? rule : rule?.countingFromCompletion
      return try commands.setRepeat(taskID: taskID, to: rule, dueIfNone: nil, log: log)
    }
  }

  /// Clears a task's due date. A repeat stays, and is counted from the day the task is done from then on.
  public func clearDue(_ taskID: TaskID) {
    perform { (log) throws(CommandError) in
      var events: [EventEnvelope] = []
      if let rule = LibraryState.replay(log).repeatRule(of: taskID) {
        events += try commands.setRepeat(taskID: taskID, to: rule.countingFromCompletion, dueIfNone: nil, log: log)
      }
      events += try commands.setDue(taskID: taskID, to: nil, isHard: false, log: log + events)
      return events
    }
  }

  /// Makes a task stop repeating; it stays, with its due date.
  public func stopRepeating(_ taskID: TaskID) {
    setRepeat(taskID, to: nil)
  }

  /// Passes over this occurrence of a repeating task: it is dropped and the next one is made.
  public func skip(_ taskID: TaskID) {
    let day = clock()
    perform { (log) throws(CommandError) in try commands.skip(taskID: taskID, today: day, log: log) }
  }

  /// Skips the selected task and selects the one that takes its place.
  public func skipSelected() {
    replaceSelected(skip)
  }
}
