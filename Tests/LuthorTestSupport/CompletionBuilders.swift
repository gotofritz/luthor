import LuthorDomain

/// Builds a `TaskReopened` envelope with short, readable defaults.
public func reopened(
  _ task: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "reopen-\(task)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskReopened(TaskReopened(taskID: TaskID(task)))
  )
}

/// Builds a `ProjectReopened` envelope with short, readable defaults.
public func projectReopened(
  _ project: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 4
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "reopen-\(project)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .projectReopened(ProjectReopened(projectID: ProjectID(project)))
  )
}
