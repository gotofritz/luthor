// Duplicating a task, deleting a task or a project for good, and turning a task into a project.
extension Commands {
  /// Makes a copy of the open item `taskID`: same title, notes, priority, estimate, due date, tags and repeat,
  /// in the same project, planned for no day, and for a project a copy of what it holds. `today` is recorded as
  /// the day the copy was made.
  public func duplicate(taskID: TaskID, today: CalendarDate? = nil, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    guard LibraryState.replay(log).isOpen(taskID) else { throw .noOpenTask(taskID.rawValue) }
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
  public func delete(projectID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    guard LibraryState.replay(log).hasProject(projectID) else { throw .unknownProject(projectID) }
    return [envelope(EventID(ids.next()), .taskDeleted(TaskDeleted(taskID: projectID)), log: log)]
  }

  /// Turns the open task `taskID` into a parallel project, to which tasks can then be added. It stays the same
  /// item, with its title, notes, fields and place. An item that is a project already writes nothing.
  public func promote(taskID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    guard let item = LibraryState.replay(log).openItem(taskID) else { throw .noOpenTask(taskID.rawValue) }
    guard item.kind == nil else { return [] }
    let changed = TaskKindChanged(taskID: taskID, kind: .parallel)
    return [envelope(EventID(ids.next()), .taskKindChanged(changed), log: log)]
  }

  /// Turns the open project `projectID` back into a task. It stays the same item, with its title, notes,
  /// fields and place. A project with an open task or sub-project in it is refused; an item that is a task
  /// already writes nothing.
  public func demote(projectID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    guard let item = state.openItem(projectID) else { throw .noOpenTask(projectID.rawValue) }
    guard item.kind != nil else { return [] }
    let project = state.view(item.viewID).projects.first { $0.id == projectID }
    guard project?.children.isEmpty ?? true else { throw .projectHasChildren(projectID) }
    let changed = TaskKindChanged(taskID: projectID, kind: nil)
    return [envelope(EventID(ids.next()), .taskKindChanged(changed), log: log)]
  }
}
