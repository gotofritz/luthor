import LuthorDomain

/// Builds a `TaskRepeatSet` envelope with short, readable defaults; a `nil` rule clears the repeat.
public func repeatSet(
  _ task: String,
  _ rule: RepeatRule?,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "repeat-\(task)-\(lamport)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskRepeatSet(TaskRepeatSet(taskID: TaskID(task), rule: rule))
  )
}

/// Builds a `TaskRecurred` envelope with short, readable defaults.
public func recurred(
  _ previous: String,
  as next: String,
  due day: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 5
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "recur-\(previous)-\(next)-\(lamport)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskRecurred(TaskRecurred(previous: TaskID(previous), next: TaskID(next), due: date(day)))
  )
}
