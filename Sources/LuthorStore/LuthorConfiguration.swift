import Foundation
import LuthorDomain

#if canImport(Glibc)
  import Glibc
#elseif canImport(Darwin)
  import Darwin
#endif

/// Where the app finds the event log, and what it calls this device.
public struct LuthorConfiguration: Equatable, Sendable {
  public let logURL: URL
  /// A folder shared between devices (`LUTHOR_SYNC_DIR`), such as one the Dropbox app syncs. When set, the
  /// log lives there, one file per device, and `logURL` is not used.
  public let syncDirectory: URL?
  public let deviceID: DeviceID

  /// `hostName` and `machineID` name the device in a shared folder when `LUTHOR_DEVICE_ID` does not: two
  /// devices must never write the same file, and two Macs can share a host name, so the name ends with the
  /// start of the machine ID. `storage`, the place the user chose, applies unless the environment sets the
  /// location itself.
  public init(
    environment: [String: String], home: URL, hostName: String = LuthorConfiguration.systemHostName(),
    machineID: String? = nil, storage: LogStorage? = nil
  ) {
    var environment = environment
    if let storage, !Self.environmentSetsLocation(environment) {
      environment.merge(storage.settings) { _, chosen in chosen }
    }
    if let path = environment["LUTHOR_LOG"], !path.isEmpty {
      logURL = URL(fileURLWithPath: path)
    } else {
      logURL = Self.defaultLogURL(home: home)
    }
    let shared = environment["LUTHOR_SYNC_DIR"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
    syncDirectory = shared
    let named = environment["LUTHOR_DEVICE_ID"].flatMap { $0.isEmpty ? nil : $0 }
    deviceID = DeviceID(named ?? (shared == nil ? "local" : Self.sharedName(host: hostName, machineID: machineID)))
  }

  /// The host name and the first eight characters of the machine ID, joined by a dash; whichever is missing
  /// is left out, and with neither the device is "local".
  private static func sharedName(host: String, machineID: String?) -> String {
    let name = [host, String((machineID ?? "").prefix(8))].filter { !$0.isEmpty }.joined(separator: "-")
    return name.isEmpty ? "local" : name
  }

  /// `~/.luthor/events.jsonl`.
  public static func defaultLogURL(home: URL) -> URL {
    home.appendingPathComponent(".luthor/events.jsonl")
  }

  /// Whether `LUTHOR_LOG` or `LUTHOR_SYNC_DIR` is set, which then wins over the place the user chose.
  public static func environmentSetsLocation(_ environment: [String: String]) -> Bool {
    ["LUTHOR_LOG", "LUTHOR_SYNC_DIR"].contains { !(environment[$0] ?? "").isEmpty }
  }

  /// The file, or the shared folder, the log lives in.
  public var location: URL { syncDirectory ?? logURL }

  /// The log to read and append to.
  public func makeEventLog() -> any EventLog {
    if let syncDirectory { return DeviceFilesEventLog(directory: syncDirectory, deviceID: deviceID) }
    return JSONLinesEventLog(fileURL: logURL)
  }

  /// Notices changes to the log made by someone else: another process, or the sync service.
  public func makeChangeMonitor() -> FileChangeMonitor {
    if let syncDirectory { return FileChangeMonitor(directoryURL: syncDirectory) }
    return FileChangeMonitor(fileURL: logURL)
  }

  /// This Mac's host name, read without a network lookup, which can stall when offline.
  public static func systemHostName() -> String {
    let capacity = 256
    var buffer = [CChar](repeating: 0, count: capacity)
    guard gethostname(&buffer, capacity) == 0 else { return "" }
    return String(bytes: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, encoding: .utf8) ?? ""
  }
}
