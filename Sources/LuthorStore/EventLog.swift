import LuthorDomain

/// Where events are read from and appended to: `JSONLinesEventLog` on disk, an in-memory fake in tests.
public protocol EventLog {
  func readAll() throws(EventLogError) -> [EventEnvelope]
  func append(_ events: [EventEnvelope]) throws(EventLogError)
  /// The readable events and the damaged lines, instead of failing at the first. Logs that cannot be damaged
  /// keep the default.
  func readReportingProblems() throws(EventLogError) -> LogReading
  /// Moves this device's damaged lines aside; returns how many. Zero by default.
  func quarantineUnreadableLines() throws(EventLogError) -> Int
}

extension EventLog {
  public func readReportingProblems() throws(EventLogError) -> LogReading { LogReading(events: try readAll()) }
  public func quarantineUnreadableLines() throws(EventLogError) -> Int { 0 }
}

extension JSONLinesEventLog: EventLog {
  public func readReportingProblems() throws(EventLogError) -> LogReading {
    try readReportingProblems(skippingIncompleteTail: false)
  }
}
