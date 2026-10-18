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

/// Builds a `ProjectDeleted` envelope with short, readable defaults.
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
    payload: .projectDeleted(ProjectDeleted(projectID: ProjectID(project)))
  )
}

/// Builds a `TaskPromotedToProject` envelope with short, readable defaults.
public func promoted(
  _ task: String,
  to project: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 5
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "promote-\(task)-\(project)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskPromoted(TaskPromotedToProject(taskID: TaskID(task), projectID: ProjectID(project)))
  )
}
