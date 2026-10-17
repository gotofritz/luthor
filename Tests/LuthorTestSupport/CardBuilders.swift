import LuthorDomain

/// Builds a `TaskRenamed` envelope with short, readable defaults.
public func renamed(
  _ task: String,
  to title: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "rename-\(task)-\(title)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskRenamed(TaskRenamed(taskID: TaskID(task), title: title))
  )
}

/// Builds a `TaskNoted` envelope with short, readable defaults; `nil` notes clear them.
public func noted(
  _ task: String,
  _ notes: String?,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "note-\(task)-\(notes ?? "none")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskNoted(TaskNoted(taskID: TaskID(task), notes: notes))
  )
}

/// Builds a `ProjectRenamed` envelope with short, readable defaults.
public func projectRenamed(
  _ project: String,
  to title: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "rename-\(project)-\(title)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .projectRenamed(ProjectRenamed(projectID: ProjectID(project), title: title))
  )
}

/// Builds a `ProjectNoted` envelope with short, readable defaults; `nil` notes clear them.
public func projectNoted(
  _ project: String,
  _ notes: String?,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "note-\(project)-\(notes ?? "none")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .projectNoted(ProjectNoted(projectID: ProjectID(project), notes: notes))
  )
}

/// Builds a `ProjectKindChanged` envelope with short, readable defaults.
public func kindChanged(
  _ project: String,
  to kind: ProjectKind,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "kind-\(project)-\(kind.rawValue)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .projectKindChanged(ProjectKindChanged(projectID: ProjectID(project), kind: kind))
  )
}
