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

  /// `hostName` names the device in a shared folder when `LUTHOR_DEVICE_ID` does not: two devices must
  /// never write the same file.
  public init(environment: [String: String], home: URL, hostName: String = LuthorConfiguration.systemHostName()) {
    if let path = environment["LUTHOR_LOG"], !path.isEmpty {
      logURL = URL(fileURLWithPath: path)
    } else {
      logURL = home.appendingPathComponent(".luthor/events.jsonl")
    }
    let shared = environment["LUTHOR_SYNC_DIR"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
    syncDirectory = shared
    let named = environment["LUTHOR_DEVICE_ID"].flatMap { $0.isEmpty ? nil : $0 }
    deviceID = DeviceID(named ?? (shared == nil || hostName.isEmpty ? "local" : hostName))
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
    return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
  }
}
