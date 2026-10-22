import Foundation
import LuthorDomain
import LuthorStore
import Observation

/// Where a compaction of the log stands.
public enum CompactionProgress: Equatable, Sendable {
  case idle
  /// This Mac asked; these Macs have not stopped writing yet, or their last events have not arrived.
  case waiting(for: [String])
  /// This Mac asked and every other Mac is ready.
  case ready
  /// Another Mac asked, and this one has stopped writing until it is done.
  case pausedForOther(String)
}

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
  /// Rebuilds the log from the library it holds; set by the app, which knows the log and reloads after it.
  public var compaction: (() throws -> LogCompaction)?
  /// The handshake with the other Macs; `nil` for a log on this Mac only, which needs none.
  public var handshake: CompactionHandshake?
  /// The time as text and a fresh ID, for requests and answers; set by the app.
  public var now: () -> String = { "" }
  public var makeID: () -> String = { UUID().uuidString }
  /// Where a compaction stands, so Settings can show it.
  public private(set) var compactionProgress = CompactionProgress.idle
  /// What the last compaction did, or why it did not happen.
  public private(set) var compactionMessage: String?

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

  /// Starts a compaction. On this Mac only it runs at once. With a shared folder it asks the other Macs to
  /// stop writing first; `finishCompaction` rebuilds the log once each has answered and its events have arrived.
  public func startCompaction() {
    guard let compaction else { return }
    guard let handshake else {
      _ = report { try compaction() }
      return
    }
    do {
      if try handshake.openRequest() == nil { _ = try handshake.request(id: makeID(), at: now()) }
      compactionMessage = nil
    } catch {
      compactionMessage = Self.describe(error)
    }
    refreshCompaction()
  }

  /// Looks at the handshake again: answers another Mac's request by stopping writing, and tells whether this
  /// Mac's own request can go ahead. Call it whenever the shared folder changes.
  public func refreshCompaction() {
    guard let handshake else { return }
    do {
      guard let open = try handshake.openRequest() else {
        compactionProgress = .idle
        return
      }
      if open.device != handshake.token {
        if try !handshake.hasAcknowledged(open) {
          try handshake.acknowledge(open, events: try handshake.ownEventCount(), at: now())
        }
        compactionProgress = .pausedForOther(open.device)
      } else {
        let waiting = try handshake.waitingFor(open)
        compactionProgress = waiting.isEmpty ? .ready : .waiting(for: waiting)
      }
    } catch {
      compactionMessage = Self.describe(error)
    }
  }

  /// Rebuilds the log for this Mac's open request. Without `force` it waits until every other Mac is ready;
  /// with it, it goes on anyway and the new events outrank any old ones that turn up later.
  public func finishCompaction(force: Bool = false) {
    guard let handshake, let compaction else { return }
    do {
      guard let open = try handshake.openRequest(), open.device == handshake.token else {
        compactionMessage = "No compaction of this Mac is waiting."
        return
      }
      let waiting = try handshake.waitingFor(open)
      if !force && !waiting.isEmpty {
        compactionMessage = "Still waiting for \(waiting.joined(separator: ", "))."
        return
      }
      guard report({ try compaction() }) else {
        try handshake.cancel(open)
        compactionProgress = .idle
        compactionMessage = (compactionMessage ?? "") + " The request is cancelled, so every Mac can write again."
        return
      }
      try handshake.finish(open, at: now())
      compactionProgress = .idle
    } catch {
      compactionMessage = Self.describe(error)
    }
  }

  /// Drops this Mac's open request, and every Mac writes again.
  public func cancelCompaction() {
    guard let handshake else { return }
    do {
      if let open = try handshake.openRequest(), open.device == handshake.token { try handshake.cancel(open) }
      compactionProgress = .idle
      compactionMessage = nil
    } catch {
      compactionMessage = Self.describe(error)
    }
  }

  /// Runs the compaction and says what happened; whether it worked.
  private func report(_ run: () throws -> LogCompaction) -> Bool {
    do {
      let result = try run()
      compactionMessage =
        "Rebuilt the log: \(result.eventsBefore) events became \(result.eventsAfter). "
        + "The old log and a YAML copy are in \(result.backupFolder.path)."
      return true
    } catch {
      compactionMessage = Self.describe(error)
      return false
    }
  }

  private static func describe(_ error: any Error) -> String {
    guard let error = error as? EventLogError else { return "\(error)" }
    switch error {
    case .ioFailure(let message): return message
    case .unreadableLine(let number): return "Line \(number) of the event log is not readable. Nothing was changed."
    }
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
