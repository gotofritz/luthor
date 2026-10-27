import Foundation
import LuthorDomain

/// Where events are read from and appended to: `JSONLinesEventLog` on disk, an in-memory fake in tests.
public protocol EventLog: Sendable {
  func readAll() throws(EventLogError) -> [EventEnvelope]
  func append(_ events: [EventEnvelope]) throws(EventLogError)
  /// The readable events and the damaged lines, instead of failing at the first. Logs that cannot be damaged
  /// keep the default.
  func readReportingProblems() throws(EventLogError) -> LogReading
  /// Moves this device's damaged lines aside; returns how many. Zero by default.
  func quarantineUnreadableLines() throws(EventLogError) -> Int
  /// Text that is the same for as long as the log's content is, found without reading it (the size and date of
  /// its files). `nil` when the log cannot tell; its reader then reads before every action.
  func changeToken() -> String?
  /// The events and damaged lines appended after `cursor`, a reading's `cursor`, and the cursor to read on from.
  /// `nil` when the log cannot tell, or was changed other than by appending (a file shortened, replaced or
  /// gone); the reader then reads the whole log. Costs what was appended, not the size of the log.
  func readIncrement(since cursor: LogCursor) throws(EventLogError) -> LogReading?
}

extension EventLog {
  public func readReportingProblems() throws(EventLogError) -> LogReading { LogReading(events: try readAll()) }
  public func quarantineUnreadableLines() throws(EventLogError) -> Int { 0 }
  public func changeToken() -> String? { nil }
  public func readIncrement(since cursor: LogCursor) throws(EventLogError) -> LogReading? { nil }
}

extension JSONLinesEventLog: EventLog {
  public func readReportingProblems() throws(EventLogError) -> LogReading {
    try readReportingProblems(skippingIncompleteTail: false)
  }

  public func readIncrement(since cursor: LogCursor) throws(EventLogError) -> LogReading? {
    let name = fileURL.lastPathComponent
    guard let (part, file) = try readIncrement(from: cursor.files[name] ?? FileCursor()) else { return nil }
    var reading = part
    reading.cursor = LogCursor(files: [name: file])
    return reading
  }

  public func changeToken() -> String? {
    let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
    guard let size = attributes?[.size] as? NSNumber, let modified = attributes?[.modificationDate] as? Date else {
      return FileManager.default.fileExists(atPath: fileURL.path) ? nil : "missing"
    }
    return "\(size)-\(modified.timeIntervalSinceReferenceDate)"
  }
}
