import LuthorDomain

// Starting and stopping a task now, on today's plan: the clock for the time a task took. In its own file
// (SwiftLint file_length) rather than suppressed.
extension LibraryViewModel {
  /// Whether the task is under way: planned for today with a start of its own that is not in the future.
  public func isRunning(_ taskID: TaskID) -> Bool {
    runningStart(of: taskID) != nil
  }

  /// The start of a task that is under way, as minutes after midnight.
  private func runningStart(of taskID: TaskID) -> Int? {
    guard planDate == today else { return nil }
    return plan.entries.first { $0.task.id == taskID }?.start.flatMap { $0 <= minuteOfDay ? $0 : nil }
  }

  /// Starts the task at the time now: the same as giving it that start time. It does nothing unless the day
  /// shown is today.
  public func startNow(_ taskID: TaskID) {
    guard planDate == today else { return }
    place(taskID, atMinute: minuteOfDay)
  }

  /// Stops a running task at the time now: the minutes since its start are added to the time logged for it
  /// today, at least one, and its start is cleared, so it is not running any more.
  public func stopNow(_ taskID: TaskID) {
    guard let start = runningStart(of: taskID) else { return }
    let day = planDate
    let elapsed = max(1, minuteOfDay - start)
    perform { (log) throws(CommandError) in
      let logged = LibraryState.replay(log).loggedMinutes(of: taskID, on: day) ?? 0
      var events = try commands.logTime(taskID: taskID, on: day, minutes: logged + elapsed, log: log)
      events += try commands.setStart(taskID: taskID, on: day, minute: nil, log: log + events)
      return events
    }
  }
}
