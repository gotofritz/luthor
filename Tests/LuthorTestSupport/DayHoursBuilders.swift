import LuthorDomain

/// Builds a `TaskStartSet` envelope in minutes after midnight; `nil` clears the start.
public func startSet(
  _ task: String,
  _ minute: Int?,
  on day: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "start-\(task)-\(day)-\(minute.map(String.init) ?? "clear")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskStartSet(TaskStartSet(taskID: TaskID(task), date: date(day), minute: minute))
  )
}

/// Builds a `DayHoursSet` envelope in minutes after midnight; `nil` clears the day's own hours.
public func dayHoursSet(
  _ start: Int?,
  _ end: Int?,
  on day: String,
  view: String = "default",
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "hours-\(view)-\(day)-\(start.map(String.init) ?? "clear")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .dayHoursSet(DayHoursSet(viewID: ViewID(view), date: date(day), start: start, end: end))
  )
}

/// Builds a `DayBlockSet` envelope: a block of untracked time in minutes after midnight.
public func blockSet(
  _ block: String,
  _ title: String,
  _ start: Int,
  _ end: Int,
  on day: String,
  view: String = "default",
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "block-\(block)-\(lamport)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .dayBlockSet(
      DayBlockSet(
        blockID: BlockID(block), viewID: ViewID(view), date: date(day), title: title, start: start, end: end))
  )
}

/// Builds a `DayBlockRemoved` envelope.
public func blockRemoved(_ block: String, id: String? = nil, device: String = "mac", lamport: UInt64 = 3)
  -> EventEnvelope
{
  EventEnvelope(
    id: EventID(id ?? "block-removed-\(block)-\(lamport)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .dayBlockRemoved(DayBlockRemoved(blockID: BlockID(block)))
  )
}

/// Builds a `TaskSessionSet` envelope: a stretch of a planned task's day set apart from the rest of it.
public func sessionSet(
  _ session: String,
  _ task: String,
  _ start: Int,
  _ minutes: Int,
  on day: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "session-\(session)-\(lamport)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskSessionSet(
      TaskSessionSet(
        sessionID: SessionID(session), taskID: TaskID(task), date: date(day), start: start, minutes: minutes))
  )
}

/// Builds a `TaskSessionRemoved` envelope.
public func sessionRemoved(_ session: String, id: String? = nil, device: String = "mac", lamport: UInt64 = 3)
  -> EventEnvelope
{
  EventEnvelope(
    id: EventID(id ?? "session-removed-\(session)-\(lamport)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskSessionRemoved(TaskSessionRemoved(sessionID: SessionID(session)))
  )
}
