import LuthorDomain

// Starting and stopping a task now, on today's plan: the clock for the time a task took. In its own file
// (SwiftLint file_length) rather than suppressed.
extension LibraryViewModel {
  /// Whether the task is under way: planned for today with a start of its own that is not in the future, and
  /// not stopped since (stopping logs time and ends the task's slot at the time now).
  public func isRunning(_ taskID: TaskID) -> Bool {
    runningStart(of: taskID) != nil
  }

  /// The start of a task that is under way, as minutes after midnight.
  private func runningStart(of taskID: TaskID) -> Int? {
    guard planDate == today, let entry = plan.entries.first(where: { $0.task.id == taskID }),
      let start = entry.start, start <= minuteOfDay
    else { return nil }
    let logged = state.loggedMinutes(of: taskID, on: planDate) != nil
    let stopped = logged && !entry.isUnestimated && start + entry.minutes <= minuteOfDay
    return stopped ? nil : start
  }

  /// Starts the task at the time now: the same as giving it that start time. It does nothing unless the day
  /// shown is today.
  public func startNow(_ taskID: TaskID) {
    guard planDate == today else { return }
    place(taskID, atMinute: minuteOfDay)
  }

  /// Stops a running task at the time now: the minutes since its start are added to the time logged for it
  /// today, at least one, and its slot, which keeps its start, now ends at the time now. The tasks after it
  /// move along if they would overlap.
  public func stopNow(_ taskID: TaskID) {
    guard let start = runningStart(of: taskID) else { return }
    let day = planDate
    let elapsed = max(1, minuteOfDay - start)
    perform { (log) throws(CommandError) in
      let logged = LibraryState.replay(log).loggedMinutes(of: taskID, on: day) ?? 0
      var events = try commands.logTime(taskID: taskID, on: day, minutes: logged + elapsed, log: log)
      events += try commands.estimate(taskID: taskID, as: elapsed, log: log + events)
      return events
    }
  }

  /// Gives a planned task a start and an end: the end sets its estimate to the minutes between them, and the
  /// tasks and blocks around it make room. Nothing happens unless the end is after the start.
  public func setTimes(_ taskID: TaskID, start: Int, end: Int) {
    guard end > start else { return }
    estimate(taskID, as: end - start)
    place(taskID, atMinute: start)
  }
}
