import LuthorDomain

/// Builds a `ReviewDefaultSet` envelope with short, readable defaults.
public func reviewDefaultSet(
  _ interval: ReviewInterval,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "review-default-\(interval.days.map(String.init) ?? "off")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .reviewDefaultSet(ReviewDefaultSet(interval: interval))
  )
}

/// Builds a `ReviewIntervalSet` envelope with short, readable defaults; a `nil` interval clears the
/// project's own interval.
public func reviewIntervalSet(
  _ project: String,
  to interval: ReviewInterval?,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "review-interval-\(project)-\(interval.map { $0.days.map(String.init) ?? "off" } ?? "clear")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .reviewIntervalSet(ReviewIntervalSet(taskID: TaskID(project), interval: interval))
  )
}

/// Builds a `TaskReviewed` envelope with short, readable defaults.
public func projectReviewed(
  _ project: String,
  on day: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "reviewed-\(project)-\(day)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskReviewed(TaskReviewed(taskID: TaskID(project), date: date(day)))
  )
}

/// Builds the `TaskDropped` envelope that drops a project, with short, readable defaults.
public func projectDropped(
  _ project: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "drop-project-\(project)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskDropped(TaskDropped(taskID: TaskID(project)))
  )
}
