import LuthorDomain
import LuthorStore

/// An event log held in memory, with switchable failures.
public final class InMemoryEventLog: EventLog, @unchecked Sendable {
  public var events: [EventEnvelope]
  /// Thrown by `readAll` while set.
  public var readFailure: EventLogError?
  /// Thrown by `append` while set; nothing is appended.
  public var appendFailure: EventLogError?

  public init(_ events: [EventEnvelope] = []) {
    self.events = events
  }

  public func readAll() throws(EventLogError) -> [EventEnvelope] {
    if let readFailure { throw readFailure }
    return events
  }

  public func append(_ events: [EventEnvelope]) throws(EventLogError) {
    if let appendFailure { throw appendFailure }
    self.events += events
  }
}
