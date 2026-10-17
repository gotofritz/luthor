import Foundation
import LuthorDomain
import LuthorStore
import Observation

/// Where the log lives, as the user chooses it: Dropbox or the Home Folder. Asked once on the first start,
/// changed later in Settings. The choice belongs to this device, so it is handed to `save` instead of going
/// into the log.
@MainActor
@Observable
public final class StorageController {
  /// The place chosen; `nil` until the user has chosen.
  public private(set) var storage: LogStorage?
  /// `LUTHOR_LOG` or `LUTHOR_SYNC_DIR` sets the place, so there is nothing to choose.
  public let lockedByEnvironment: Bool
  /// The radio buttons and the folder field, as edited and not yet confirmed.
  public var kind: LogStorage.Kind
  public var dropboxFolderPath: String
  public private(set) var errorMessage: String?

  private let home: URL
  private let deviceID: DeviceID
  private let save: (LogStorage) -> Void

  public init(
    saved: LogStorage?, home: URL, deviceID: DeviceID, lockedByEnvironment: Bool = false,
    save: @escaping (LogStorage) -> Void
  ) {
    storage = saved
    self.lockedByEnvironment = lockedByEnvironment
    kind = saved?.kind ?? .dropbox
    dropboxFolderPath = (saved?.dropboxFolder ?? LogStorage.defaultDropboxFolder(home: home)).path
    self.home = home
    self.deviceID = deviceID
    self.save = save
  }

  /// Whether the user has still to choose, so the app asks before it opens a log.
  public var needsSetup: Bool { storage == nil && !lockedByEnvironment }

  /// Takes the place as edited into use: makes its folders, remembers the choice, and sets `storage`.
  /// A place that cannot be used sets `errorMessage` and changes nothing.
  public func confirm() {
    let typed = dropboxFolderPath.trimmingCharacters(in: .whitespacesAndNewlines)
    if kind == .dropbox && typed.isEmpty {
      errorMessage = "Choose a folder for Dropbox."
      return
    }
    let chosen = LogStorage(kind: kind, dropboxFolder: typed.isEmpty ? defaultFolder : folder(typed))
    do {
      try chosen.prepare(home: home, deviceID: deviceID)
    } catch {
      errorMessage = Self.message(for: error)
      return
    }
    save(chosen)
    storage = chosen
    errorMessage = nil
  }

  private var defaultFolder: URL { LogStorage.defaultDropboxFolder(home: home) }

  private func folder(_ typed: String) -> URL {
    typed.hasPrefix("~/")
      ? home.appendingPathComponent(String(typed.dropFirst(2))) : URL(fileURLWithPath: typed)
  }

  private static func message(for error: EventLogError) -> String {
    switch error {
    case .ioFailure(let message): "Cannot use that place: \(message)"
    case .unreadableLine: "Cannot use that place."
    }
  }
}
