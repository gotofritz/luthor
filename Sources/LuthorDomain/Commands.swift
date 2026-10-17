/// Source of unique IDs for new events and tasks. Injected so tests stay deterministic.
public protocol IDGenerator {
  func next() -> String
}

public enum CommandError: Error, Equatable {
  case blankTitle
  case noOpenTask(String)
  case ambiguousPrefix(String, matches: [TaskID])
  case noActiveProject(ProjectID)
  case noView(ViewID)
  case duplicateViewName(String)
  /// The task and the project are in different views; only a move to the view takes a task across.
  case otherView(TaskID, ProjectID)
  /// The project and the one it would be nested in are in different views.
  case projectInOtherView(ProjectID, parent: ProjectID)
  /// A project cannot be nested under itself or one of its own sub-projects.
  case nestedUnderItself(ProjectID)
}

/// Turns user intentions into new events, given the current log.
public struct Commands {
  let deviceID: DeviceID
  let ids: any IDGenerator

  public init(deviceID: DeviceID, ids: any IDGenerator) {
    self.deviceID = deviceID
    self.ids = ids
  }

  /// Captures a task into the inbox of the view `viewID`.
  public func capture(title: String, in viewID: ViewID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    let title = try Self.named(title)
    try requireView(viewID, in: LibraryState.replay(log))
    return [captureEvent(title: title, viewID: viewID, log: log).event]
  }

  /// Captures a task straight into the active project `projectID`, in the project's view.
  public func capture(
    title: String,
    into projectID: ProjectID,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let title = try Self.named(title)
    let project = try activeProject(projectID, in: LibraryState.replay(log))
    let (capture, taskID) = captureEvent(title: title, viewID: project.viewID, log: log)
    return try [capture] + move(taskID: taskID, to: projectID, log: log + [capture])
  }

  /// Completes the one open task of the view `viewID` whose ID starts with `idPrefix`, ignoring case.
  public func complete(
    idPrefix: String,
    in viewID: ViewID,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let prefix = idPrefix.lowercased()
    let matches = LibraryState.replay(log).view(viewID).openTasks
      .map(\.id)
      .filter { !prefix.isEmpty && $0.rawValue.lowercased().hasPrefix(prefix) }
    guard let match = matches.first else { throw .noOpenTask(idPrefix) }
    guard matches.count == 1 else { throw .ambiguousPrefix(idPrefix, matches: matches) }
    return [envelope(EventID(ids.next()), .taskCompleted(TaskCompleted(taskID: match)), log: log)]
  }

  /// Completes the open task with exactly this ID.
  public func complete(taskID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    guard LibraryState.replay(log).openTasks.contains(where: { $0.id == taskID }) else {
      throw .noOpenTask(taskID.rawValue)
    }
    return [envelope(EventID(ids.next()), .taskCompleted(TaskCompleted(taskID: taskID)), log: log)]
  }

  public func createProject(
    title: String,
    kind: ProjectKind,
    in viewID: ViewID,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let title = try Self.named(title)
    try requireView(viewID, in: LibraryState.replay(log))
    let eventID = EventID(ids.next())
    let created = ProjectCreated(projectID: ProjectID(ids.next()), title: title, kind: kind, viewID: viewID)
    return [envelope(eventID, .projectCreated(created), log: log)]
  }

  /// Creates a project inside the active project `parentID`, in the parent's view.
  public func createProject(
    title: String,
    kind: ProjectKind,
    under parentID: ProjectID,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    []
  }

  /// Nests the active project `projectID` in the active project `parentID` of its view; with no parent,
  /// makes it top-level. Nesting a project where it already is writes nothing.
  public func move(
    projectID: ProjectID,
    under parentID: ProjectID?,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    []
  }

  public func createView(name: String, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    let name = try Self.named(name)
    try requireUnique(name, in: LibraryState.replay(log))
    let eventID = EventID(ids.next())
    return [envelope(eventID, .viewCreated(ViewCreated(viewID: ViewID(ids.next()), name: name)), log: log)]
  }

  public func renameView(_ viewID: ViewID, to name: String, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let name = try Self.named(name)
    let state = LibraryState.replay(log)
    try requireView(viewID, in: state)
    try requireUnique(name, except: viewID, in: state)
    return [envelope(EventID(ids.next()), .viewRenamed(ViewRenamed(viewID: viewID, name: name)), log: log)]
  }

  /// Takes the open task `taskID` across to the view `viewID`, into its inbox. Moving a task into the
  /// view it is in writes nothing.
  public func move(taskID: TaskID, toView viewID: ViewID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope]
  {
    let state = LibraryState.replay(log)
    guard let task = state.openTasks.first(where: { $0.id == taskID }) else { throw .noOpenTask(taskID.rawValue) }
    try requireView(viewID, in: state)
    guard task.viewID != viewID else { return [] }
    return [envelope(EventID(ids.next()), .taskMovedToView(TaskMovedToView(taskID: taskID, viewID: viewID)), log: log)]
  }

  /// Takes the active project `projectID` and its open tasks across to the view `viewID`. Moving a
  /// project into the view it is in writes nothing.
  public func move(
    projectID: ProjectID,
    toView viewID: ViewID,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    let project = try activeProject(projectID, in: state)
    try requireView(viewID, in: state)
    guard project.viewID != viewID else { return [] }
    let moved = ProjectMovedToView(projectID: projectID, viewID: viewID)
    return [envelope(EventID(ids.next()), .projectMovedToView(moved), log: log)]
  }

  /// Files the open task `taskID` into the active project `projectID`, which must be in the task's view.
  /// Filing a task where it already is writes nothing.
  public func move(
    taskID: TaskID,
    to projectID: ProjectID,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    guard let task = state.openTasks.first(where: { $0.id == taskID }) else { throw .noOpenTask(taskID.rawValue) }
    let project = try activeProject(projectID, in: state)
    guard task.viewID == project.viewID else { throw .otherView(taskID, projectID) }
    guard task.projectID != projectID else { return [] }
    let moved = TaskMovedToProject(taskID: taskID, projectID: projectID)
    return [envelope(EventID(ids.next()), .taskMovedToProject(moved), log: log)]
  }

  public func completeProject(_ projectID: ProjectID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    try requireActive(projectID, log: log)
    return [envelope(EventID(ids.next()), .projectCompleted(ProjectCompleted(projectID: projectID)), log: log)]
  }

  private func requireActive(_ projectID: ProjectID, log: [EventEnvelope]) throws(CommandError) {
    _ = try activeProject(projectID, in: LibraryState.replay(log))
  }

  private func activeProject(_ projectID: ProjectID, in state: LibraryState) throws(CommandError) -> Project {
    guard let project = state.projects.first(where: { $0.id == projectID }) else { throw .noActiveProject(projectID) }
    return project
  }

  private func requireView(_ viewID: ViewID, in state: LibraryState) throws(CommandError) {
    guard state.hasView(viewID) else { throw .noView(viewID) }
  }

  /// Throws unless no view but `viewID` has this name, in any case.
  private func requireUnique(_ name: String, except viewID: ViewID? = nil, in state: LibraryState) throws(CommandError)
  {
    if let existing = state.view(named: name), existing.id != viewID { throw .duplicateViewName(name) }
  }

  private func captureEvent(title: String, viewID: ViewID, log: [EventEnvelope]) -> (
    event: EventEnvelope, taskID: TaskID
  ) {
    let eventID = EventID(ids.next())
    let taskID = TaskID(ids.next())
    let captured = TaskCaptured(taskID: taskID, title: title, viewID: viewID)
    return (envelope(eventID, .taskCaptured(captured), log: log), taskID)
  }

  /// The title or name without surrounding whitespace; throws if nothing is left.
  private static func named(_ title: String) throws(CommandError) -> String {
    let trimmed = String(title.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
    guard !trimmed.isEmpty else { throw .blankTitle }
    return trimmed
  }

  private func envelope(_ id: EventID, _ payload: EventPayload, log: [EventEnvelope]) -> EventEnvelope {
    EventEnvelope(id: id, deviceID: deviceID, lamport: (log.map(\.lamport).max() ?? 0) + 1, payload: payload)
  }
}
