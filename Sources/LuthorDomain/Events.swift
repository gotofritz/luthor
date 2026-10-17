public struct TaskCaptured: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let title: String

  public init(taskID: TaskID, title: String) {
    self.taskID = taskID
    self.title = title
  }
}

public enum EventPayload: Equatable, Sendable {
  case taskCaptured(TaskCaptured)
  case taskCompleted(TaskCompleted)
  case projectCreated(ProjectCreated)
  case taskMovedToProject(TaskMovedToProject)
  case projectCompleted(ProjectCompleted)
}

/// One entry in the event log: a payload plus the metadata replay orders by.
public struct EventEnvelope: Equatable, Sendable {
  public let id: EventID
  public let deviceID: DeviceID
  /// Lamport counter; the primary ordering key.
  public let lamport: UInt64
  public let payload: EventPayload

  public init(id: EventID, deviceID: DeviceID, lamport: UInt64, payload: EventPayload) {
    self.id = id
    self.deviceID = deviceID
    self.lamport = lamport
    self.payload = payload
  }
}

public struct TaskCompleted: Equatable, Codable, Sendable {
  public let taskID: TaskID

  public init(taskID: TaskID) {
    self.taskID = taskID
  }
}

/// How a project hands out its next actions.
public enum ProjectKind: String, Codable, Sendable {
  /// Every open task can be worked on at once.
  case parallel
  /// Only the first open task can be worked on; the rest wait their turn.
  case sequential
}

public struct ProjectCreated: Equatable, Codable, Sendable {
  public let projectID: ProjectID
  public let title: String
  public let kind: ProjectKind

  public init(projectID: ProjectID, title: String, kind: ProjectKind) {
    self.projectID = projectID
    self.title = title
    self.kind = kind
  }
}

/// Files a task into a project, from the inbox or from another project.
public struct TaskMovedToProject: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let projectID: ProjectID

  public init(taskID: TaskID, projectID: ProjectID) {
    self.taskID = taskID
    self.projectID = projectID
  }
}

/// Completes a project together with the tasks still open in it.
public struct ProjectCompleted: Equatable, Codable, Sendable {
  public let projectID: ProjectID

  public init(projectID: ProjectID) {
    self.projectID = projectID
  }
}

extension EventEnvelope {
  /// Total order for replay: Lamport counter, then device ID, then event ID.
  public static func replayOrder(_ lhs: EventEnvelope, _ rhs: EventEnvelope) -> Bool {
    (lhs.lamport, lhs.deviceID, lhs.id) < (rhs.lamport, rhs.deviceID, rhs.id)
  }
}
