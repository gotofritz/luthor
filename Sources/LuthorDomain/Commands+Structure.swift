// Duplicating a task, deleting a task or a project for good, and turning a task into a project.
extension Commands {
  /// Makes a copy of the open task `taskID`: same title, notes, priority, estimate, due date, tags and repeat,
  /// in the same project, planned for no day. `today` is recorded as the day the copy was made.
  public func duplicate(taskID: TaskID, today: CalendarDate? = nil, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    guard LibraryState.replay(log).openTasks.contains(where: { $0.id == taskID }) else {
      throw .noOpenTask(taskID.rawValue)
    }
    let eventID = EventID(ids.next())
    let duplicated = TaskDuplicated(source: taskID, copy: TaskID(ids.next()), createdOn: today)
    return [envelope(eventID, .taskDuplicated(duplicated), log: log)]
  }

  /// Deletes the task `taskID` for good, open or completed, with everything set on it.
  public func delete(taskID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    guard LibraryState.replay(log).hasTask(taskID) else { throw .unknownTask(taskID) }
    return [envelope(EventID(ids.next()), .taskDeleted(TaskDeleted(taskID: taskID)), log: log)]
  }

  /// Deletes the project `projectID` for good, active, dropped or completed, with its sub-projects and every
  /// task in them.
  public func delete(projectID: ProjectID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    guard LibraryState.replay(log).hasProject(projectID) else { throw .unknownProject(projectID) }
    return [envelope(EventID(ids.next()), .projectDeleted(ProjectDeleted(projectID: projectID)), log: log)]
  }

  /// Turns the open task `taskID` into a project, to which tasks can then be added. It keeps the task's title,
  /// notes and place; see `TaskPromotedToProject` for what is let go.
  public func promote(taskID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    guard LibraryState.replay(log).openTasks.contains(where: { $0.id == taskID }) else {
      throw .noOpenTask(taskID.rawValue)
    }
    let eventID = EventID(ids.next())
    let promoted = TaskPromotedToProject(taskID: taskID, projectID: ProjectID(ids.next()))
    return [envelope(eventID, .taskPromoted(promoted), log: log)]
  }
}
