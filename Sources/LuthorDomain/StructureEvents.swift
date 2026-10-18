/// Makes the open task `copy` out of the task `source`, which is open or completed: in its project if that is
/// active and in its view, else loose, with its title, notes, priority, estimate, due date, tags and repeat.
/// Not the day planned, a delegation or logged time.
public struct TaskDuplicated: Equatable, Codable, Sendable {
  public let source: TaskID
  public let copy: TaskID
  /// The day the copy was made; `nil` when the day was not known.
  public let createdOn: CalendarDate?

  public init(source: TaskID, copy: TaskID, createdOn: CalendarDate? = nil) {
    self.source = source
    self.copy = copy
    self.createdOn = createdOn
  }
}

/// Removes an item for good, open, completed or dropped, with everything set on it and every item filed in it,
/// at any depth. Unlike `TaskDropped`, which gives an item up, nothing of it is left to show or to bring back.
public struct TaskDeleted: Equatable, Codable, Sendable {
  public let taskID: TaskID

  public init(taskID: TaskID) {
    self.taskID = taskID
  }
}
