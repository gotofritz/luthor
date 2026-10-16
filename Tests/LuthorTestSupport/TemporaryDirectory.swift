import Foundation

/// A fresh directory under the system temp dir, so tests never touch real data.
public struct TemporaryDirectory {
  public let url: URL

  public init() throws {
    url = FileManager.default.temporaryDirectory
      .appendingPathComponent("luthor-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }

  public func file(_ name: String) -> URL {
    url.appendingPathComponent(name)
  }

  public func remove() {
    try? FileManager.default.removeItem(at: url)
  }
}
