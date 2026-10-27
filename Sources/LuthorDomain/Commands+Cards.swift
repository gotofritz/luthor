/// What a card edits: the title, notes and (for a project) kind of a task or project.
extension Commands {
  /// Gives the open task `taskID` another title. A blank title is refused; the title it has writes nothing.
  public func rename(taskID: TaskID, to title: String, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    let title = try Self.named(title)
    let task = try openTask(taskID, in: libraryState(from: log))
    guard task.title != title else { return [] }
    return [envelope(EventID(ids.next()), .taskRenamed(TaskRenamed(taskID: taskID, title: title)), log: log)]
  }

  /// Sets the notes of the open task `taskID`; blank notes clear them. The notes it has write nothing.
  public func setNotes(taskID: TaskID, to notes: String, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let task = try openTask(taskID, in: libraryState(from: log))
    let notes = Self.noteText(notes)
    guard task.notes != notes else { return [] }
    return [envelope(EventID(ids.next()), .taskNoted(TaskNoted(taskID: taskID, notes: notes)), log: log)]
  }

  /// Adds a bullet to the notes of the open task or project `taskID` for each non-blank line of `text`, after
  /// the bullets it has. Blank text writes nothing.
  public func appendNote(taskID: TaskID, _ text: String, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let task = try openTask(taskID, in: libraryState(from: log))
    let added = NoteBullets.bullets(in: text)
    guard !added.isEmpty else { return [] }
    let notes = NoteBullets.notes(from: NoteBullets.bullets(in: task.notes) + added)
    return try setNotes(taskID: taskID, to: notes, log: log)
  }

  /// Deletes the bullet at `position` from the notes of the open task or project `taskID`. A position with no
  /// bullet writes nothing.
  public func deleteNote(taskID: TaskID, at position: Int, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let task = try openTask(taskID, in: libraryState(from: log))
    var bullets = NoteBullets.bullets(in: task.notes)
    guard bullets.indices.contains(position) else { return [] }
    bullets.remove(at: position)
    return try setNotes(taskID: taskID, to: NoteBullets.notes(from: bullets), log: log)
  }

  /// Replaces the bullet at `position` in the notes of the open task or project `taskID` with `text`, one bullet
  /// for each non-blank line of it; blank text deletes the bullet. A position with no bullet, or the same text,
  /// writes nothing.
  public func editNote(taskID: TaskID, at position: Int, to text: String, log: [EventEnvelope])
    throws(CommandError) -> [EventEnvelope]
  {
    let task = try openTask(taskID, in: libraryState(from: log))
    var bullets = NoteBullets.bullets(in: task.notes)
    guard bullets.indices.contains(position) else { return [] }
    bullets.replaceSubrange(position...position, with: NoteBullets.bullets(in: text))
    return try setNotes(taskID: taskID, to: NoteBullets.notes(from: bullets), log: log)
  }

  /// Gives the active project `projectID` another title. A blank title is refused; the title it has writes
  /// nothing.
  public func renameProject(_ projectID: TaskID, to title: String, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let title = try Self.named(title)
    let project = try activeProject(projectID, in: libraryState(from: log))
    guard project.title != title else { return [] }
    let renamed = TaskRenamed(taskID: projectID, title: title)
    return [envelope(EventID(ids.next()), .taskRenamed(renamed), log: log)]
  }

  /// Makes the open item `projectID` sequential or parallel, a project if it was not one. The kind it has writes
  /// nothing.
  public func setKind(of projectID: TaskID, to kind: ProjectKind, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let state = libraryState(from: log)
    guard let item = state.openItem(projectID) else { throw .noActiveProject(projectID) }
    guard item.kind != kind else { return [] }
    let changed = TaskKindChanged(taskID: projectID, kind: kind)
    return [envelope(EventID(ids.next()), .taskKindChanged(changed), log: log)]
  }

  /// Sets the notes of the active project `projectID`; blank notes clear them. The notes it has write
  /// nothing.
  public func setNotes(ofProject projectID: TaskID, to notes: String, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let project = try activeProject(projectID, in: libraryState(from: log))
    let notes = Self.noteText(notes)
    guard project.notes != notes else { return [] }
    let noted = TaskNoted(taskID: projectID, notes: notes)
    return [envelope(EventID(ids.next()), .taskNoted(noted), log: log)]
  }

  private func openTask(_ taskID: TaskID, in state: LibraryState) throws(CommandError) -> TaskItem {
    guard let task = state.openItem(taskID) else { throw .noOpenTask(taskID.rawValue) }
    return task
  }

  /// The notes without surrounding whitespace; `nil` if nothing is left.
  private static func noteText(_ notes: String) -> String? {
    let trimmed = trimmed(notes)
    return trimmed.isEmpty ? nil : trimmed
  }
}
