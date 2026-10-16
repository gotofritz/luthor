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

extension EventEnvelope {
  /// Total order for replay: Lamport counter, then device ID, then event ID.
  public static func replayOrder(_ lhs: EventEnvelope, _ rhs: EventEnvelope) -> Bool {
    (lhs.lamport, lhs.deviceID, lhs.id) < (rhs.lamport, rhs.deviceID, rhs.id)
  }
}
