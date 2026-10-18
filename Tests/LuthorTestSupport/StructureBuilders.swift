import LuthorDomain

/// Builds a `TaskDuplicated` envelope with short, readable defaults.
public func duplicated(
  _ source: String,
  as copy: String,
  on day: String? = nil,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 5
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "duplicate-\(source)-\(copy)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskDuplicated(
      TaskDuplicated(source: TaskID(source), copy: TaskID(copy), createdOn: day.map(date)))
  )
}

/// Builds a `TaskDeleted` envelope with short, readable defaults.
public func taskDeleted(
  _ task: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 9
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "delete-\(task)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskDeleted(TaskDeleted(taskID: TaskID(task)))
  )
}

/// Builds the `TaskDeleted` envelope that deletes a project, with short, readable defaults.
public func projectDeleted(
  _ project: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 9
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "delete-\(project)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskDeleted(TaskDeleted(taskID: TaskID(project)))
  )
}

/// Builds the `TaskKindChanged` envelope that turns a task into a parallel project, with short, readable
/// defaults.
public func promoted(
  _ task: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 5
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "promote-\(task)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskKindChanged(TaskKindChanged(taskID: TaskID(task), kind: .parallel))
  )
}

/// Builds the `TaskKindChanged` envelope that turns a project back into a task, with short, readable defaults.
public func demoted(
  _ project: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 5
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "demote-\(project)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskKindChanged(TaskKindChanged(taskID: TaskID(project), kind: nil))
  )
}
