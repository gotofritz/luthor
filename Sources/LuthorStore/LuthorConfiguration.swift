import Foundation
import LuthorDomain

/// Where the CLI and the app find the event log, and what they call this device. Both read it the same
/// way, so they share one log unless told otherwise.
public struct LuthorConfiguration: Equatable, Sendable {
  public let logURL: URL
  public let deviceID: DeviceID

  public init(environment: [String: String], home: URL) {
    if let path = environment["LUTHOR_LOG"], !path.isEmpty {
      logURL = URL(fileURLWithPath: path)
    } else {
      logURL = home.appendingPathComponent(".luthor/events.jsonl")
    }
    deviceID = DeviceID(environment["LUTHOR_DEVICE_ID"].flatMap { $0.isEmpty ? nil : $0 } ?? "local")
  }
}
