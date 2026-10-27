import Foundation
import LuthorDomain

/// The event log of a folder shared by several devices, such as one synced by the Dropbox app.
///
/// Each device appends only to its own file, `events-<device>.jsonl`, so two devices never write the same
/// file and the sync service never has a conflict to resolve. Reading merges every device's file; replay
/// orders and de-duplicates the events, so it does not matter in what order the files arrive.
public struct DeviceFilesEventLog: EventLog, Sendable {
  public let directory: URL
  public let deviceID: DeviceID

  public init(directory: URL, deviceID: DeviceID) {
    self.directory = directory
    self.deviceID = deviceID
  }

  /// The file name of the device's own log: anything outside letters, digits, `.`, `_` and `-` becomes `-`.
  public static func fileName(for deviceID: DeviceID) -> String {
    let safe = deviceID.rawValue.unicodeScalars.map { scalar in
      scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || "._-".unicodeScalars.contains(scalar))
        ? Character(scalar) : "-"
    }
    return prefix + String(safe) + suffix
  }

  /// Whether a file name belongs to a device log. A conflict copy the sync service might make of one still
  /// does, and reading it is harmless: replay applies each event once.
  public static func isDeviceLog(named name: String) -> Bool {
    name.hasPrefix(prefix) && name.hasSuffix(suffix)
  }

  private static let prefix = "events-"
  private static let suffix = ".jsonl"

  private var ownFileName: String { Self.fileName(for: deviceID) }

  /// Every device's events, the files in name order. A missing folder is an empty log. Another device's
  /// half-synced last line is skipped; any other unreadable line is an error.
  public func readAll() throws(EventLogError) -> [EventEnvelope] {
    var events: [EventEnvelope] = []
    for name in try deviceLogNames() {
      events += try file(name).readAll(skippingIncompleteTail: name != ownFileName)
    }
    return events
  }

  /// Like `readAll`, but every damaged line is reported with its file and line instead of being an error.
  public func readReportingProblems() throws(EventLogError) -> LogReading {
    var reading = LogReading()
    for name in try deviceLogNames() {
      let part = try file(name).readReportingProblems(skippingIncompleteTail: name != ownFileName)
      reading.events += part.events
      reading.problems += part.problems
    }
    return reading
  }

  /// The names, sizes and dates of every device's file; `nil` if any cannot be told.
  public func changeToken() -> String? {
    guard let names = try? deviceLogNames() else { return nil }
    var parts: [String] = []
    for name in names {
      guard let token = file(name).changeToken() else { return nil }
      parts.append("\(name):\(token)")
    }
    return parts.joined(separator: ",")
  }

  /// Repairs this device's own file only; another device's file is theirs to repair.
  public func quarantineUnreadableLines() throws(EventLogError) -> Int {
    try file(ownFileName).quarantineUnreadableLines()
  }

  private func file(_ name: String) -> JSONLinesEventLog {
    JSONLinesEventLog(fileURL: directory.appendingPathComponent(name))
  }

  private func deviceLogNames() throws(EventLogError) -> [String] {
    do {
      guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
      return try FileManager.default.contentsOfDirectory(atPath: directory.path)
        .filter(Self.isDeviceLog(named:)).sorted()
    } catch {
      throw .ioFailure("cannot list \(directory.path): \(error)")
    }
  }

  /// Appends to this device's own file only.
  public func append(_ events: [EventEnvelope]) throws(EventLogError) {
    try JSONLinesEventLog(fileURL: directory.appendingPathComponent(ownFileName)).append(events)
  }
}
