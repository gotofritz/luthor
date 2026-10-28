import Foundation
import LuthorDomain

/// Where this device keeps the event log, as the user chose it. It lives outside the log, which has to be
/// found first, so each device remembers its own choice.
public struct LogStorage: Equatable, Sendable {
  public enum Kind: String, CaseIterable, Sendable {
    /// A folder the Dropbox desktop app syncs, one log file per device.
    case dropbox
    /// The single file `~/.luthor/events.jsonl`, on this Mac only.
    case homeFolder = "home"
  }

  public let kind: Kind
  /// The Dropbox folder. It is kept while the Home Folder is chosen, so switching back finds it again.
  public let dropboxFolder: URL

  public init(kind: Kind, dropboxFolder: URL) {
    self.kind = kind
    self.dropboxFolder = dropboxFolder
  }

  /// `~/Dropbox/backups/Luthor`.
  public static func defaultDropboxFolder(home: URL) -> URL {
    home.appendingPathComponent("Dropbox/backups/Luthor")
  }

  /// Reads a choice written down with `kindName` and `dropboxFolder.path`; `nil` when none was written
  /// (or the name is not one of ours), meaning the user has still to choose.
  public init?(kindName: String?, dropboxFolderPath: String?, home: URL) {
    guard let kindName, let kind = Kind(rawValue: kindName) else { return nil }
    self.init(
      kind: kind,
      dropboxFolder: dropboxFolderPath.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0) }
        ?? Self.defaultDropboxFolder(home: home))
  }

  public var kindName: String { kind.rawValue }

  /// The environment settings this choice stands for, as `LuthorConfiguration` reads them.
  public var settings: [String: String] {
    switch kind {
    case .dropbox: ["LUTHOR_SYNC_DIR": dropboxFolder.path]
    case .homeFolder: [:]
    }
  }

  /// How the folder of the log stands, as far as the file system shows.
  public enum FolderStatus: Equatable, Sendable {
    /// The Home Folder is chosen: nothing syncs, nothing to check.
    case localOnly
    /// The folder is inside a folder the Dropbox desktop app manages, this one.
    case inDropbox(root: URL)
    /// The folder exists but no Dropbox folder is above it, so nothing will sync it.
    case notInDropbox
    /// There is no folder there: it was deleted, moved or never made.
    case missing
  }

  /// Looks at the folder now. Dropbox marks the root it syncs with a hidden `.dropbox` item, so the folder
  /// counts as synced when it or a folder above it holds one.
  public func folderStatus() -> FolderStatus {
    guard kind == .dropbox else { return .localOnly }
    let files = FileManager.default
    var isDirectory: ObjCBool = false
    guard files.fileExists(atPath: dropboxFolder.path, isDirectory: &isDirectory), isDirectory.boolValue
    else { return .missing }
    var candidate = dropboxFolder.standardizedFileURL
    while true {
      if files.fileExists(atPath: candidate.appendingPathComponent(".dropbox").path) {
        return .inDropbox(root: candidate)
      }
      let parent = candidate.deletingLastPathComponent()
      if parent.path == candidate.path { return .notInDropbox }
      candidate = parent
    }
  }

  /// Makes the place ready to use. Dropbox creates its folder and the ones above it, and copies the log
  /// of the Home Folder in as this device's file the first time, so the tasks come along; it never
  /// overwrites a file already there, and the original stays. The Home Folder needs nothing.
  public func prepare(home: URL, deviceID: DeviceID) throws(EventLogError) {
    guard kind == .dropbox else { return }
    let files = FileManager.default
    do {
      try files.createDirectory(at: dropboxFolder, withIntermediateDirectories: true)
    } catch {
      throw .ioFailure("cannot create \(dropboxFolder.path): \(error)")
    }
    let homeLog = LuthorConfiguration.defaultLogURL(home: home)
    let deviceFile = dropboxFolder.appendingPathComponent(DeviceFilesEventLog.fileName(for: deviceID))
    guard files.fileExists(atPath: homeLog.path), !files.fileExists(atPath: deviceFile.path) else { return }
    do {
      try files.copyItem(at: homeLog, to: deviceFile)
    } catch {
      throw .ioFailure("cannot copy \(homeLog.path) to \(deviceFile.path): \(error)")
    }
  }
}
