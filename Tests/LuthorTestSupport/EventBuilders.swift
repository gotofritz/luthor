import LuthorDomain

/// Builds a `TaskCaptured` envelope with short, readable defaults.
public func captured(
  _ task: String,
  _ title: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 1
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "capture-\(task)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskCaptured(TaskCaptured(taskID: TaskID(task), title: title))
  )
}

/// Builds a `TaskCompleted` envelope with short, readable defaults.
public func completed(
  _ task: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "complete-\(task)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskCompleted(TaskCompleted(taskID: TaskID(task)))
  )
}

public func item(_ task: String, _ title: String) -> TaskItem {
  TaskItem(id: TaskID(task), title: title)
}
