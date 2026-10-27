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

  /// Stops a running task at the time now: the run, from its start to now, becomes a session, and the minutes
  /// of it are added to the time logged for the task today. The task keeps its estimate, and what is left of it
  /// follows the other tasks. Later tasks move along if the session overlaps them.
  public func stopNow(_ taskID: TaskID) {
    guard let start = runningStart(of: taskID) else { return }
    let day = planDate
    let elapsed = min(max(1, minuteOfDay - start), dayLimit - start)
    perform { (log) throws(CommandError) in
      let logged = state.loggedMinutes(of: taskID, on: day) ?? 0
      var events = try commands.logTime(taskID: taskID, on: day, minutes: logged + elapsed, log: log)
      events += try commands.setStart(taskID: taskID, on: day, minute: nil, log: log + events)
      events += try commands.setSession(of: taskID, on: day, start: start, minutes: elapsed, log: log + events)
      return events
    }
    if let session = plan.sessions.first(where: { $0.task.id == taskID && $0.start == start }) {
      placeSession(session.id, atMinute: start)
    }
  }

  /// Gives a planned task's own block a start and an end: the minutes between them, and those of its sessions,
  /// are its estimate, and the tasks and blocks around it make room. Nothing happens unless the end is after
  /// the start.
  public func setTimes(_ taskID: TaskID, start: Int, end: Int) {
    guard end > start else { return }
    let inSessions = plan.sessions.filter { $0.task.id == taskID }.reduce(0) { $0 + $1.minutes }
    estimate(taskID, as: end - start + inSessions)
    place(taskID, atMinute: start)
  }

  /// Gives a planned task that follows the others the start it has now, so it keeps its place on the calendar
  /// once it is done.
  func pinPlace(of taskID: TaskID) {
    guard plan.entries.first(where: { $0.task.id == taskID })?.start == nil,
      let slot = planSlots.first(where: { $0.entry.task.id == taskID })
    else { return }
    place(taskID, atMinute: slot.start)
  }
}
