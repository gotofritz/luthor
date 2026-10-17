public struct TaskCaptured: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let title: String
  public let viewID: ViewID

  public init(taskID: TaskID, title: String, viewID: ViewID) {
    self.taskID = taskID
    self.title = title
    self.viewID = viewID
  }

  /// Events written before views have no `viewID`; they belong to the default view.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    taskID = try container.decode(TaskID.self, forKey: .taskID)
    title = try container.decode(String.self, forKey: .title)
    viewID = try container.decodeIfPresent(ViewID.self, forKey: .viewID) ?? .default
  }
}

public enum EventPayload: Equatable, Sendable {
  case taskCaptured(TaskCaptured)
  case taskCompleted(TaskCompleted)
  case projectCreated(ProjectCreated)
  case taskMovedToProject(TaskMovedToProject)
  case projectCompleted(ProjectCompleted)
  case viewCreated(ViewCreated)
  case viewRenamed(ViewRenamed)
  case taskMovedToView(TaskMovedToView)
  case projectMovedToView(ProjectMovedToView)
  case projectMovedToProject(ProjectMovedToProject)
  case taskPrioritized(TaskPrioritized)
  case taskEstimated(TaskEstimated)
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
  public let viewID: ViewID
  /// The project it is created in; `nil` for a top-level project.
  public let parentID: ProjectID?

  public init(projectID: ProjectID, title: String, kind: ProjectKind, viewID: ViewID, parentID: ProjectID? = nil) {
    self.projectID = projectID
    self.title = title
    self.kind = kind
    self.viewID = viewID
    self.parentID = parentID
  }

  /// Events written before views have no `viewID`; they belong to the default view. Events written before
  /// nesting have no `parentID`; they are top-level.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    projectID = try container.decode(ProjectID.self, forKey: .projectID)
    title = try container.decode(String.self, forKey: .title)
    kind = try container.decode(ProjectKind.self, forKey: .kind)
    viewID = try container.decodeIfPresent(ViewID.self, forKey: .viewID) ?? .default
    parentID = try container.decodeIfPresent(ProjectID.self, forKey: .parentID)
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

public struct ViewCreated: Equatable, Codable, Sendable {
  public let viewID: ViewID
  public let name: String

  public init(viewID: ViewID, name: String) {
    self.viewID = viewID
    self.name = name
  }
}

public struct ViewRenamed: Equatable, Codable, Sendable {
  public let viewID: ViewID
  public let name: String

  public init(viewID: ViewID, name: String) {
    self.viewID = viewID
    self.name = name
  }
}

/// Takes a task across to another view, out of its project and into that view's inbox.
public struct TaskMovedToView: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let viewID: ViewID

  public init(taskID: TaskID, viewID: ViewID) {
    self.taskID = taskID
    self.viewID = viewID
  }
}

/// Takes a project across to another view, together with its open tasks.
public struct ProjectMovedToView: Equatable, Codable, Sendable {
  public let projectID: ProjectID
  public let viewID: ViewID

  public init(projectID: ProjectID, viewID: ViewID) {
    self.projectID = projectID
    self.viewID = viewID
  }
}

/// Nests a project in another of its view, or with no parent makes it top-level again.
public struct ProjectMovedToProject: Equatable, Codable, Sendable {
  public let projectID: ProjectID
  /// The project it is nested in from now on; `nil` makes it top-level.
  public let parentID: ProjectID?

  public init(projectID: ProjectID, parentID: ProjectID?) {
    self.projectID = projectID
    self.parentID = parentID
  }
}

/// How much a task matters. Importance only: never order, deadline or day.
public enum Priority: String, Codable, Sendable, CaseIterable {
  /// A: must be addressed today.
  case critical = "A"
  /// B: meaningfully advances what matters.
  case important = "B"
  /// C: do when capacity remains.
  case optional = "C"
  /// Not committed to; kept for one day.
  case someday
}

/// Gives an open task a priority, or with none clears it.
public struct TaskPrioritized: Equatable, Codable, Sendable {
  public let taskID: TaskID
  /// The priority from now on; `nil` clears it.
  public let priority: Priority?

  public init(taskID: TaskID, priority: Priority?) {
    self.taskID = taskID
    self.priority = priority
  }
}

/// Gives an open task an estimate in minutes, or with none clears it.
public struct TaskEstimated: Equatable, Codable, Sendable {
  public let taskID: TaskID
  /// Minutes the task is expected to take; `nil` clears it.
  public let minutes: Int?

  public init(taskID: TaskID, minutes: Int?) {
    self.taskID = taskID
    self.minutes = minutes
  }
}

extension EventEnvelope {
  /// Total order for replay: Lamport counter, then device ID, then event ID.
  public static func replayOrder(_ lhs: EventEnvelope, _ rhs: EventEnvelope) -> Bool {
    (lhs.lamport, lhs.deviceID, lhs.id) < (rhs.lamport, rhs.deviceID, rhs.id)
  }
}
