import Foundation
import LuthorDomain

/// Random lowercase UUIDs, for real use. Tests inject a deterministic generator instead.
public struct UUIDGenerator: IDGenerator {
  public init() {}

  public func next() -> String {
    UUID().uuidString.lowercased()
  }
}
