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
    let names: [String]
    do {
      guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
      names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    } catch {
      throw .ioFailure("cannot list \(directory.path): \(error)")
    }
    var events: [EventEnvelope] = []
    for name in names.filter(Self.isDeviceLog(named:)).sorted() {
      let file = JSONLinesEventLog(fileURL: directory.appendingPathComponent(name))
      events += try file.readAll(skippingIncompleteTail: name != ownFileName)
    }
    return events
  }

  /// Appends to this device's own file only.
  public func append(_ events: [EventEnvelope]) throws(EventLogError) {
    try JSONLinesEventLog(fileURL: directory.appendingPathComponent(ownFileName)).append(events)
  }
}
