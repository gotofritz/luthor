import LuthorDomain

/// Builds a `TagCreated` envelope with short, readable defaults.
public func tagCreated(
  _ tag: String,
  _ name: String,
  view: String = "default",
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 1
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "create-tag-\(tag)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .tagCreated(TagCreated(tagID: TagID(tag), name: name, viewID: ViewID(view)))
  )
}

/// Builds a `TaskTagged` envelope with short, readable defaults.
public func tagged(
  _ task: String,
  with tag: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "tag-\(task)-\(tag)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskTagged(TaskTagged(taskID: TaskID(task), tagID: TagID(tag)))
  )
}

/// Builds a `TaskUntagged` envelope with short, readable defaults.
public func untagged(
  _ task: String,
  from tag: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "untag-\(task)-\(tag)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskUntagged(TaskUntagged(taskID: TaskID(task), tagID: TagID(tag)))
  )
}
