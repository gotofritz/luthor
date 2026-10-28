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

/// Puts the items filed in a project in an order. The items named come first, in the order given; those filed in
/// the project and not named keep their order after them. Ignored for a name that is not filed in the project,
/// a name that comes a second time, and a project that is not open.
public struct ChildrenOrdered: Equatable, Codable, Sendable {
  public let parentID: TaskID
  public let taskIDs: [TaskID]

  public init(parentID: TaskID, taskIDs: [TaskID]) {
    self.parentID = parentID
    self.taskIDs = taskIDs
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
