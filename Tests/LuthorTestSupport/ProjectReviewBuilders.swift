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

/// Builds a `ProjectReviewIntervalSet` envelope with short, readable defaults; a `nil` interval clears the
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
    payload: .projectReviewIntervalSet(ProjectReviewIntervalSet(projectID: ProjectID(project), interval: interval))
  )
}

/// Builds a `ProjectReviewed` envelope with short, readable defaults.
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
    payload: .projectReviewed(ProjectReviewed(projectID: ProjectID(project), date: date(day)))
  )
}

/// Builds a `ProjectPutOnHold` envelope with short, readable defaults.
public func projectPutOnHold(
  _ project: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "hold-\(project)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .projectPutOnHold(ProjectPutOnHold(projectID: ProjectID(project)))
  )
}

/// Builds a `ProjectResumed` envelope with short, readable defaults.
public func projectResumed(
  _ project: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 4
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "resume-\(project)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .projectResumed(ProjectResumed(projectID: ProjectID(project)))
  )
}

/// Builds a `ProjectDropped` envelope with short, readable defaults.
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
    payload: .projectDropped(ProjectDropped(projectID: ProjectID(project)))
  )
}
