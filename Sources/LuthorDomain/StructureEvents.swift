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

/// Removes a task for good, open or completed, with everything set on it. Unlike `TaskDropped`, which gives a
/// task up, nothing of it is left to show or to bring back.
public struct TaskDeleted: Equatable, Codable, Sendable {
  public let taskID: TaskID

  public init(taskID: TaskID) {
    self.taskID = taskID
  }
}

/// Removes a project for good, active, dropped or completed, with its sub-projects and every task in them.
public struct ProjectDeleted: Equatable, Codable, Sendable {
  public let projectID: ProjectID

  public init(projectID: ProjectID) {
    self.projectID = projectID
  }
}

/// Turns an open task into the project `projectID`: it keeps its title, notes, view, the day it was created and
/// its place in the project it was filed in, which becomes the new project's parent. What only a task can hold
/// (priority, estimate, due date, tags, repeat, a day planned, a delegation) is let go.
public struct TaskPromotedToProject: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let projectID: ProjectID

  public init(taskID: TaskID, projectID: ProjectID) {
    self.taskID = taskID
    self.projectID = projectID
  }
}
