/// Source of unique IDs for new events and tasks. Injected so tests stay deterministic.
public protocol IDGenerator {
  func next() -> String
}

public enum CommandError: Error, Equatable {
  case blankTitle
  case noOpenTask(String)
  case ambiguousPrefix(String, matches: [TaskID])
  case noActiveProject(ProjectID)
}

/// Turns user intentions into new events, given the current log.
public struct Commands {
  let deviceID: DeviceID
  let ids: any IDGenerator

  public init(deviceID: DeviceID, ids: any IDGenerator) {
    self.deviceID = deviceID
    self.ids = ids
  }

  /// Captures a task into the inbox, or straight into the active project `projectID`.
  public func capture(
    title: String,
    into projectID: ProjectID? = nil,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let title = Self.trimmed(title)
    guard !title.isEmpty else { throw .blankTitle }
    if let projectID { try requireActive(projectID, log: log) }
    let eventID = EventID(ids.next())
    let taskID = TaskID(ids.next())
    let capture = envelope(eventID, .taskCaptured(TaskCaptured(taskID: taskID, title: title)), log: log)
    guard let projectID else { return [capture] }
    return try [capture] + move(taskID: taskID, to: projectID, log: log + [capture])
  }

  /// Completes the one open task whose ID starts with `idPrefix`, ignoring case.
  public func complete(idPrefix: String, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    let prefix = idPrefix.lowercased()
    let matches = LibraryState.replay(log).openTasks
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
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let title = Self.trimmed(title)
    guard !title.isEmpty else { throw .blankTitle }
    let eventID = EventID(ids.next())
    let created = ProjectCreated(projectID: ProjectID(ids.next()), title: title, kind: kind)
    return [envelope(eventID, .projectCreated(created), log: log)]
  }

  /// Files the open task `taskID` into the active project `projectID`. Filing a task where it already
  /// is writes nothing.
  public func move(
    taskID: TaskID,
    to projectID: ProjectID,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    guard let task = state.openTasks.first(where: { $0.id == taskID }) else { throw .noOpenTask(taskID.rawValue) }
    try requireActive(projectID, in: state)
    guard task.projectID != projectID else { return [] }
    let moved = TaskMovedToProject(taskID: taskID, projectID: projectID)
    return [envelope(EventID(ids.next()), .taskMovedToProject(moved), log: log)]
  }

  public func completeProject(_ projectID: ProjectID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    try requireActive(projectID, log: log)
    return [envelope(EventID(ids.next()), .projectCompleted(ProjectCompleted(projectID: projectID)), log: log)]
  }

  private func requireActive(_ projectID: ProjectID, log: [EventEnvelope]) throws(CommandError) {
    try requireActive(projectID, in: LibraryState.replay(log))
  }

  private func requireActive(_ projectID: ProjectID, in state: LibraryState) throws(CommandError) {
    guard state.projects.contains(where: { $0.id == projectID }) else { throw .noActiveProject(projectID) }
  }

  private static func trimmed(_ title: String) -> String {
    String(title.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
  }

  private func envelope(_ id: EventID, _ payload: EventPayload, log: [EventEnvelope]) -> EventEnvelope {
    EventEnvelope(id: id, deviceID: deviceID, lamport: (log.map(\.lamport).max() ?? 0) + 1, payload: payload)
  }
}
