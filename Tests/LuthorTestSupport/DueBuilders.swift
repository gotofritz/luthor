import LuthorDomain

/// Builds a `TaskDueSet` envelope with short, readable defaults; a `nil` day clears the due date.
public func dueSet(
  _ task: String,
  on day: String?,
  hard: Bool = true,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "due-\(task)-\(day ?? "none")-\(hard ? "hard" : "target")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskDueSet(TaskDueSet(taskID: TaskID(task), date: day.map(date), isHard: day != nil && hard))
  )
}
