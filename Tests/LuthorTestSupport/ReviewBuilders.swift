import LuthorDomain

/// Builds a `TaskTimeLogged` envelope with short, readable defaults; `nil` minutes clears the day's time.
public func timeLogged(
  _ task: String,
  on day: String,
  minutes: Int?,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "time-\(task)-\(day)-\(minutes.map(String.init) ?? "clear")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskTimeLogged(TaskTimeLogged(taskID: TaskID(task), date: date(day), minutes: minutes))
  )
}

/// Builds an `UnplannedTimeLogged` envelope with short, readable defaults; `nil` minutes clears the day's time.
public func unplannedTimeLogged(
  _ minutes: Int?,
  on day: String,
  view: String = "default",
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "unplanned-\(view)-\(day)-\(minutes.map(String.init) ?? "clear")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .unplannedTimeLogged(UnplannedTimeLogged(viewID: ViewID(view), date: date(day), minutes: minutes))
  )
}

/// Builds a `DayReviewed` envelope with short, readable defaults.
public func dayReviewed(
  on day: String,
  note: String? = nil,
  view: String = "default",
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 4
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "review-\(view)-\(day)-\(note ?? "")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .dayReviewed(DayReviewed(viewID: ViewID(view), date: date(day), note: note))
  )
}
