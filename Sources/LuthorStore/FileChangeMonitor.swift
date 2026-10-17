import Foundation

/// Notices when a file changes by polling its size and modification date.
///
/// Polling, unlike a file-descriptor watch, also sees a file that is created late, deleted or replaced.
public struct FileChangeMonitor {
  private struct Signature: Equatable {
    let size: UInt64
    let modified: Date
  }

  public let fileURL: URL
  private var last: Signature?

  public init(fileURL: URL) {
    self.fileURL = fileURL
    last = Self.signature(of: fileURL)
  }

  /// Whether the file changed since the monitor was made or last polled.
  public mutating func poll() -> Bool {
    let current = Self.signature(of: fileURL)
    defer { last = current }
    return current != last
  }

  /// `nil` when the file cannot be inspected: missing, or unreadable. Polling never throws; a reader
  /// that reloads on the change reports the real error.
  private static func signature(of url: URL) -> Signature? {
    let attributes: [FileAttributeKey: Any]
    do {
      attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    } catch {
      return nil
    }
    guard let size = attributes[.size] as? NSNumber, let modified = attributes[.modificationDate] as? Date else {
      return nil
    }
    return Signature(size: size.uint64Value, modified: modified)
  }
}
