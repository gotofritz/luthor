/// What a card edits: the title, notes and (for a project) kind of a task or project.
extension Commands {
  /// Gives the open task `taskID` another title. A blank title is refused; the title it has writes nothing.
  public func rename(taskID: TaskID, to title: String, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    let title = try Self.named(title)
    let task = try openTask(taskID, in: LibraryState.replay(log))
    guard task.title != title else { return [] }
    return [envelope(EventID(ids.next()), .taskRenamed(TaskRenamed(taskID: taskID, title: title)), log: log)]
  }

  /// Sets the notes of the open task `taskID`; blank notes clear them. The notes it has write nothing.
  public func setNotes(taskID: TaskID, to notes: String, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let task = try openTask(taskID, in: LibraryState.replay(log))
    let notes = Self.noteText(notes)
    guard task.notes != notes else { return [] }
    return [envelope(EventID(ids.next()), .taskNoted(TaskNoted(taskID: taskID, notes: notes)), log: log)]
  }

  /// Gives the active project `projectID` another title. A blank title is refused; the title it has writes
  /// nothing.
  public func renameProject(_ projectID: TaskID, to title: String, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let title = try Self.named(title)
    let project = try activeProject(projectID, in: LibraryState.replay(log))
    guard project.title != title else { return [] }
    let renamed = TaskRenamed(taskID: projectID, title: title)
    return [envelope(EventID(ids.next()), .taskRenamed(renamed), log: log)]
  }

  /// Makes the active project `projectID` sequential or parallel. The kind it has writes nothing.
  public func setKind(of projectID: TaskID, to kind: ProjectKind, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let project = try activeProject(projectID, in: LibraryState.replay(log))
    guard project.kind != kind else { return [] }
    let changed = TaskKindChanged(taskID: projectID, kind: kind)
    return [envelope(EventID(ids.next()), .taskKindChanged(changed), log: log)]
  }

  /// Sets the notes of the active project `projectID`; blank notes clear them. The notes it has write
  /// nothing.
  public func setNotes(ofProject projectID: TaskID, to notes: String, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let project = try activeProject(projectID, in: LibraryState.replay(log))
    let notes = Self.noteText(notes)
    guard project.notes != notes else { return [] }
    let noted = TaskNoted(taskID: projectID, notes: notes)
    return [envelope(EventID(ids.next()), .taskNoted(noted), log: log)]
  }

  private func openTask(_ taskID: TaskID, in state: LibraryState) throws(CommandError) -> TaskItem {
    guard let task = state.openTasks.first(where: { $0.id == taskID }) else { throw .noOpenTask(taskID.rawValue) }
    return task
  }

  /// The notes without surrounding whitespace; `nil` if nothing is left.
  private static func noteText(_ notes: String) -> String? {
    let trimmed = trimmed(notes)
    return trimmed.isEmpty ? nil : trimmed
  }
}
