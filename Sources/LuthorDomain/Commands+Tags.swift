/// Tags: creating them, and putting them on tasks or taking them off. A tag belongs to the view of the task
/// it is put on, and is named without the `@` the lists show it with.
extension Commands {
  /// Creates a tag in the view `viewID`. A leading `@` and surrounding space are not part of the name; a blank
  /// name is refused, and so is one the view has already, in any case.
  public func createTag(named name: String, in viewID: ViewID, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let state = LibraryState.replay(log)
    try requireView(viewID, in: state)
    let name = try Self.tagName(name)
    guard state.tag(named: name, in: viewID) == nil else { throw .duplicateTagName(name) }
    return [newTag(name, in: viewID, log: log).event]
  }

  /// Puts the tag `tagID` on the open task `taskID`, which must be in the tag's view. Tagging a task with a
  /// tag it has writes nothing.
  public func tag(taskID: TaskID, with tagID: TagID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    guard let task = state.openItem(taskID) else { throw .noOpenTask(taskID.rawValue) }
    guard let found = state.tagItems.first(where: { $0.id == tagID }) else { throw .noTag(tagID) }
    guard found.viewID == task.viewID else { throw .tagInOtherView(taskID, tagID) }
    guard !state.tags(of: taskID).contains(where: { $0.id == tagID }) else { return [] }
    return [envelope(EventID(ids.next()), .taskTagged(TaskTagged(taskID: taskID, tagID: tagID)), log: log)]
  }

  /// Takes the tag `tagID` off the open task `taskID`. Taking off a tag the task does not carry writes
  /// nothing.
  public func untag(taskID: TaskID, from tagID: TagID, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let state = LibraryState.replay(log)
    guard state.isOpen(taskID) else { throw .noOpenTask(taskID.rawValue) }
    guard state.tags(of: taskID).contains(where: { $0.id == tagID }) else { return [] }
    return [envelope(EventID(ids.next()), .taskUntagged(TaskUntagged(taskID: taskID, tagID: tagID)), log: log)]
  }

  /// Puts the tag called `name` on the open task `taskID`, creating the tag in the task's view if the view
  /// has none of that name (in any case, with or without the `@`). A task that has the tag writes nothing.
  public func tag(taskID: TaskID, named name: String, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let state = LibraryState.replay(log)
    guard let task = state.openItem(taskID) else { throw .noOpenTask(taskID.rawValue) }
    let name = try Self.tagName(name)
    var events: [EventEnvelope] = []
    let tagID: TagID
    if let existing = state.tag(named: name, in: task.viewID) {
      tagID = existing.id
    } else {
      let created = newTag(name, in: task.viewID, log: log)
      events = [created.event]
      tagID = created.id
    }
    return try events + tag(taskID: taskID, with: tagID, log: log + events)
  }

  /// Gives the open task `taskID` exactly these tags, by name: it is put on those it lacks, creating tags the
  /// view lacks, and taken off those that are not named. Blank names are skipped and a name given twice counts
  /// once. The tags it has writes nothing.
  public func setTags(taskID: TaskID, to names: [String], log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let state = LibraryState.replay(log)
    guard state.isOpen(taskID) else { throw .noOpenTask(taskID.rawValue) }
    var wanted: [String] = []
    for name in names.map(Self.cleanTagName) where !name.isEmpty {
      if !wanted.contains(where: { $0.lowercased() == name.lowercased() }) { wanted.append(name) }
    }
    var events: [EventEnvelope] = []
    for name in wanted {
      events += try tag(taskID: taskID, named: name, log: log + events)
    }
    let kept = Set(wanted.map { $0.lowercased() })
    for carried in state.tags(of: taskID) where !kept.contains(carried.name.lowercased()) {
      events += try untag(taskID: taskID, from: carried.id, log: log + events)
    }
    return events
  }

  /// A new tag, with the event that creates it.
  private func newTag(_ name: String, in viewID: ViewID, log: [EventEnvelope]) -> (id: TagID, event: EventEnvelope) {
    let eventID = EventID(ids.next())
    let created = TagCreated(tagID: TagID(ids.next()), name: name, viewID: viewID)
    return (created.tagID, envelope(eventID, .tagCreated(created), log: log))
  }

  /// The name without surrounding space and a leading `@`; throws if nothing is left.
  static func tagName(_ name: String) throws(CommandError) -> String {
    let clean = cleanTagName(name)
    guard !clean.isEmpty else { throw .blankTitle }
    return clean
  }

  /// The name without surrounding space and a leading `@`; empty if nothing is left.
  public static func cleanTagName(_ name: String) -> String {
    trimmed(String(trimmed(name).drop(while: { $0 == "@" })))
  }
}
