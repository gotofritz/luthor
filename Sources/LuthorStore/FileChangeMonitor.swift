import Foundation

/// Notices when a log changes by polling the size and modification date of its file, or of every device
/// log in its folder.
///
/// Polling, unlike a file-descriptor watch, also sees a file that is created late, deleted or replaced.
public struct FileChangeMonitor {
  private struct Signature: Equatable {
    let name: String
    let size: UInt64
    let modified: Date
  }

  /// What was watched, so a new, removed or changed file is told apart from an untouched one.
  private enum Target {
    case file(URL)
    case deviceLogs(folder: URL)
  }

  private let target: Target
  private var last: [Signature]

  public init(fileURL: URL) {
    target = .file(fileURL)
    last = Self.signatures(of: target)
  }

  /// Watches every device log (`events-<device>.jsonl`) in the folder, as `DeviceFilesEventLog` writes them,
  /// and the files of the compaction handshake.
  public init(directoryURL: URL) {
    target = .deviceLogs(folder: directoryURL)
    last = Self.signatures(of: target)
  }

  /// Whether the file or folder changed since the monitor was made or last polled.
  public mutating func poll() -> Bool {
    let current = Self.signatures(of: target)
    defer { last = current }
    return current != last
  }

  /// Empty when nothing can be inspected: missing, or unreadable. Polling never throws; a reader that
  /// reloads on the change reports the real error.
  private static func signatures(of target: Target) -> [Signature] {
    switch target {
    case .file(let url):
      return signature(of: url).map { [$0] } ?? []
    case .deviceLogs(let folder):
      let names: [String]
      do {
        names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
      } catch {
        return []
      }
      return names.filter { DeviceFilesEventLog.isDeviceLog(named: $0) || isCompactionFile($0) }.sorted().compactMap {
        signature(of: folder.appendingPathComponent($0))
      }
    }
  }

  /// A request or an answer of the compaction handshake.
  private static func isCompactionFile(_ name: String) -> Bool {
    name.hasPrefix("compaction-") && name.hasSuffix(".json")
  }

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
    return Signature(name: url.lastPathComponent, size: size.uint64Value, modified: modified)
  }
}
