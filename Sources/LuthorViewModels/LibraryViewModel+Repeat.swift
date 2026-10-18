import LuthorDomain

// Repeating tasks: giving a task a rule, skipping one occurrence, and stopping the series. Completing a task that
// repeats makes the next one in `complete(_:)`. In its own file (SwiftLint file_length) rather than suppressed.
extension LibraryViewModel {
  /// How a task repeats; `nil` if it does not.
  public func repeatRule(of taskID: TaskID) -> RepeatRule? {
    state.repeatRule(of: taskID)
  }

  /// Makes a task repeat by `rule`, or with `nil` stops it. A task with no due date is given the day Today
  /// shows, as a target date, to count from.
  public func setRepeat(_ taskID: TaskID, to rule: RepeatRule?) {
    let day = planDate
    perform { (log) throws(CommandError) in
      try commands.setRepeat(taskID: taskID, to: rule, dueIfNone: day, log: log)
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
