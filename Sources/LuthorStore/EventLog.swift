import LuthorDomain

/// Where events are read from and appended to: `JSONLinesEventLog` on disk, an in-memory fake in tests.
public protocol EventLog {
  func readAll() throws(EventLogError) -> [EventEnvelope]
  func append(_ events: [EventEnvelope]) throws(EventLogError)
}

extension JSONLinesEventLog: EventLog {}
