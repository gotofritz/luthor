extension Commands {
  /// Sets apart `minutes` of a task's day from `start` as a session; with an ID, changes that session instead.
  /// The task has to be planned for the day.
  public func setSession(
    _ sessionID: SessionID? = nil,
    of taskID: TaskID,
    on date: CalendarDate,
    start: Int,
    minutes: Int,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = libraryState(from: log)
    guard state.isOpen(taskID) else { throw .unknownTask(taskID) }
    guard minutes > 0, (0..<DayHours.latest).contains(start), start + minutes <= DayHours.latest else {
      throw .invalidSession
    }
    if let sessionID {
      guard let session = state.taskSessions[sessionID] else { throw .noSession(sessionID) }
      guard session.start != start || session.minutes != minutes else { return [] }
    }
    let event = TaskSessionSet(
      sessionID: sessionID ?? SessionID(ids.next()), taskID: taskID, date: date, start: start, minutes: minutes)
    return [envelope(EventID(ids.next()), .taskSessionSet(event), log: log)]
  }

  /// Gives a session's minutes back to its task.
  public func removeSession(_ sessionID: SessionID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    guard libraryState(from: log).taskSessions[sessionID] != nil else { throw .noSession(sessionID) }
    return [envelope(EventID(ids.next()), .taskSessionRemoved(TaskSessionRemoved(sessionID: sessionID)), log: log)]
  }
}
