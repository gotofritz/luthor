/// Sets apart a stretch of a planned task's day, or changes the one with this ID: the task is done on and off
/// through the day. The task's own block shrinks by the minutes of its sessions. Times are minutes after midnight.
public struct TaskSessionSet: Equatable, Codable, Sendable {
  public let sessionID: SessionID
  public let taskID: TaskID
  public let date: CalendarDate
  public let start: Int
  public let minutes: Int

  public init(sessionID: SessionID, taskID: TaskID, date: CalendarDate, start: Int, minutes: Int) {
    self.sessionID = sessionID
    self.taskID = taskID
    self.date = date
    self.start = start
    self.minutes = minutes
  }
}

/// Gives a session's minutes back to the task's own block.
public struct TaskSessionRemoved: Equatable, Codable, Sendable {
  public let sessionID: SessionID

  public init(sessionID: SessionID) {
    self.sessionID = sessionID
  }
}
