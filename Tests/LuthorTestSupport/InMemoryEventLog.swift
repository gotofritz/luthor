import LuthorDomain
import LuthorStore

/// An event log held in memory, with switchable failures.
public final class InMemoryEventLog: EventLog, @unchecked Sendable {
  public var events: [EventEnvelope]
  /// Thrown by `readAll` while set.
  public var readFailure: EventLogError?
  /// Thrown by `append` while set; nothing is appended.
  public var appendFailure: EventLogError?

  /// How many times the log was read.
  public private(set) var reads = 0

  public init(_ events: [EventEnvelope] = []) {
    self.events = events
  }

  public func readAll() throws(EventLogError) -> [EventEnvelope] {
    reads += 1
    if let readFailure { throw readFailure }
    return events
  }

  /// The number of events, or none while reads fail, so a reader reads and meets the failure.
  public func changeToken() -> String? {
    readFailure == nil ? "\(events.count)" : nil
  }

  public func append(_ events: [EventEnvelope]) throws(EventLogError) {
    if let appendFailure { throw appendFailure }
    self.events += events
  }
}
