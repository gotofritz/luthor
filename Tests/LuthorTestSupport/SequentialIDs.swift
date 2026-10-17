import LuthorDomain

/// Deterministic ID generator: "id-1", "id-2", …
public final class SequentialIDs: IDGenerator, @unchecked Sendable {
  private var counter = 0

  public init() {}

  public func next() -> String {
    counter += 1
    return "id-\(counter)"
  }
}
