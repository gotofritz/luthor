import Foundation
import LuthorDomain

/// Random lowercase UUIDs, for the CLI and the app. Tests inject a deterministic generator instead.
public struct UUIDGenerator: IDGenerator {
  public init() {}

  public func next() -> String {
    UUID().uuidString.lowercased()
  }
}
