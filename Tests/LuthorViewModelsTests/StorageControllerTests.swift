import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("When Luthor starts and the log has no place chosen")
struct StorageControllerTests {
  private final class Saved {
    var choices: [LogStorage] = []
  }

  private func controller(
    in home: TemporaryDirectory, saved: LogStorage? = nil, lockedByEnvironment: Bool = false,
    into record: Saved = Saved()
  ) -> StorageController {
    StorageController(
      saved: saved, home: home.url, deviceID: DeviceID("desk"), lockedByEnvironment: lockedByEnvironment,
      save: { record.choices.append($0) })
  }

  @Test("it asks, and offers Dropbox with its default folder")
  func asksWithDropboxPreselected() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }

    let controller = controller(in: home)

    #expect(controller.needsSetup)
    #expect(controller.kind == .dropbox)
    #expect(controller.dropboxFolderPath == LogStorage.defaultDropboxFolder(home: home.url).path)
  }

  @Test("choosing Dropbox makes its folders, remembers the choice and stops asking")
  func choosingDropbox() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let record = Saved()
    let controller = controller(in: home, into: record)

    controller.confirm()

    #expect(controller.needsSetup == false)
    #expect(controller.storage?.kind == .dropbox)
    #expect(record.choices == [try #require(controller.storage)])
    #expect(FileManager.default.fileExists(atPath: home.file("Dropbox/backups/Luthor").path))
  }

  @Test("choosing the Home Folder remembers the choice and makes no folder")
  func choosingHomeFolder() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let record = Saved()
    let controller = controller(in: home, into: record)

    controller.kind = .homeFolder
    controller.confirm()

    #expect(controller.storage?.kind == .homeFolder)
    #expect(record.choices.count == 1)
    #expect(!FileManager.default.fileExists(atPath: home.file("Dropbox").path))
  }

  @Test("a path starting with ~/ is taken from the home folder")
  func tildeMeansHome() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let controller = controller(in: home)

    controller.dropboxFolderPath = "~/Sync/Luthor"
    controller.confirm()

    #expect(controller.storage?.dropboxFolder.path == home.file("Sync/Luthor").path)
  }

  @Test("Dropbox with no folder typed is refused, and nothing is remembered")
  func blankFolderIsRefused() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let record = Saved()
    let controller = controller(in: home, into: record)

    controller.dropboxFolderPath = "  "
    controller.confirm()

    #expect(controller.errorMessage != nil)
    #expect(controller.needsSetup)
    #expect(record.choices.isEmpty)
  }

  @Test("a folder that cannot be made is refused with a message, and nothing is remembered")
  func unmakeableFolderIsRefused() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    try "a file".write(to: home.file("Dropbox"), atomically: true, encoding: .utf8)
    let record = Saved()
    let controller = controller(in: home, into: record)

    controller.confirm()

    #expect(controller.errorMessage != nil)
    #expect(controller.needsSetup)
    #expect(record.choices.isEmpty)
  }

  @Test("a place already chosen is not asked for again, and starts the drafts")
  func chosenPlaceIsKept() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let saved = LogStorage(kind: .homeFolder, dropboxFolder: home.file("Other"))

    let controller = controller(in: home, saved: saved)

    #expect(controller.needsSetup == false)
    #expect(controller.storage == saved)
    #expect(controller.kind == .homeFolder)
    #expect(controller.dropboxFolderPath == home.file("Other").path)
  }

  @Test("a place set by the environment is never asked for")
  func environmentPlaceIsNeverAsked() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }

    let controller = controller(in: home, lockedByEnvironment: true)

    #expect(controller.needsSetup == false)
    #expect(controller.lockedByEnvironment)
  }
}

@MainActor
@Suite("When the Dropbox folder is checked")
struct FolderStatusTests {
  private func controller(in home: TemporaryDirectory, saved: LogStorage? = nil) -> StorageController {
    StorageController(saved: saved, home: home.url, deviceID: DeviceID("desk"), save: { _ in })
  }

  private func makeDropbox(in home: TemporaryDirectory) throws {
    try FileManager.default.createDirectory(
      at: home.file("Dropbox/.dropbox"), withIntermediateDirectories: true)
  }

  @Test("a folder that is not in a real Dropbox is accepted, with a warning")
  func foldersOutsideDropboxWarn() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let controller = controller(in: home)

    controller.confirm()

    #expect(controller.storage?.kind == .dropbox)
    #expect(controller.folderStatus == .notInDropbox)
    #expect(controller.folderWarning?.contains("not inside a Dropbox folder") == true)
  }

  @Test("a folder inside a real Dropbox has no warning")
  func foldersInDropboxAreQuiet() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    try makeDropbox(in: home)
    let controller = controller(in: home)

    controller.confirm()

    #expect(controller.folderStatus == .inDropbox(root: URL(fileURLWithPath: home.file("Dropbox").path, isDirectory: true)))
    #expect(controller.folderWarning == nil)
  }

  @Test("a folder that disappears is noticed when the status is refreshed")
  func disappearingFolderWarns() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    try makeDropbox(in: home)
    let controller = controller(in: home)
    controller.confirm()

    try FileManager.default.removeItem(at: home.file("Dropbox/backups"))
    controller.refreshFolderStatus()

    #expect(controller.folderStatus == .missing)
    #expect(controller.folderWarning?.contains("cannot be found") == true)
  }

  @Test("a saved folder is checked when Luthor starts")
  func savedFolderIsChecked() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let saved = LogStorage(kind: .dropbox, dropboxFolder: home.file("Moved/Luthor"))

    #expect(controller(in: home, saved: saved).folderStatus == .missing)
  }

  @Test("the Home Folder has nothing to warn about")
  func homeFolderIsQuiet() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let saved = LogStorage(kind: .homeFolder, dropboxFolder: home.file("Dropbox/backups/Luthor"))

    let controller = controller(in: home, saved: saved)

    #expect(controller.folderStatus == .localOnly)
    #expect(controller.folderWarning == nil)
  }
}

@MainActor
@Suite("When the log is compacted from Settings")
struct CompactLogTests {
  private final class Runs {
    var count = 0
    var isEmpty: Bool { count < 1 }
  }

  private func controller(
    _ home: TemporaryDirectory, shared device: String? = nil, runs: Runs = Runs()
  ) -> StorageController {
    let controller = StorageController(saved: nil, home: home.url, deviceID: DeviceID("desk"), save: { _ in })
    if let device {
      controller.handshake = CompactionHandshake(directory: home.url, deviceID: DeviceID(device))
    }
    controller.makeID = { "r1" }
    controller.now = { ISO8601DateFormatter().string(from: Date()) }
    controller.compaction = {
      runs.count += 1
      return LogCompaction(eventsBefore: 900, eventsAfter: 40, backupFolder: home.file("backups/compact-s"))
    }
    return controller
  }

  private func writeEvents(_ count: Int, as device: String, in home: TemporaryDirectory) throws {
    try DeviceFilesEventLog(directory: home.url, deviceID: DeviceID(device)).append(
      (1...count).map {
        captured("\(device)\($0)", "task", id: "\(device)-\($0)", device: device, lamport: UInt64($0))
      })
  }

  @Test("on this Mac only it runs at once and reports the backup and the events before and after")
  func itRunsAtOnceWithoutAHandshake() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let runs = Runs()
    let controller = controller(home, runs: runs)

    controller.startCompaction()

    #expect(runs.count == 1)
    #expect(controller.compactionMessage?.contains("900") == true)
    #expect(controller.compactionMessage?.contains("40") == true)
    #expect(controller.compactionMessage?.contains(home.file("backups/compact-s").path) == true)
  }

  @Test("a failure is reported")
  func aFailureIsReported() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let controller = controller(home)
    controller.compaction = { throw EventLogError.ioFailure("disk full") }

    controller.startCompaction()

    #expect(controller.compactionMessage?.contains("disk full") == true)
  }

  @Test("with a shared folder it waits for the other Mac, which stops writing when it sees the request")
  func itWaitsForTheOtherMac() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    try writeEvents(2, as: "mac", in: home)
    try writeEvents(3, as: "laptop", in: home)
    let runs = Runs()
    let mac = controller(home, shared: "mac", runs: runs)
    let laptop = controller(home, shared: "laptop")

    mac.startCompaction()
    #expect(mac.compactionProgress == .waiting(for: ["laptop"]))
    #expect(runs.isEmpty)

    laptop.refreshCompaction()
    #expect(laptop.compactionProgress == .pausedForOther("mac"))

    mac.refreshCompaction()
    #expect(mac.compactionProgress == .ready)
  }

  @Test("finishing rebuilds the log once and lets the other Mac write again")
  func finishingRebuildsOnce() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    try writeEvents(1, as: "mac", in: home)
    try writeEvents(1, as: "laptop", in: home)
    let runs = Runs()
    let mac = controller(home, shared: "mac", runs: runs)
    let laptop = controller(home, shared: "laptop")
    mac.startCompaction()
    laptop.refreshCompaction()
    mac.refreshCompaction()

    mac.finishCompaction()
    laptop.refreshCompaction()

    #expect(runs.count == 1)
    #expect(mac.compactionProgress == .idle)
    #expect(laptop.compactionProgress == .idle)
  }

  @Test("it does not go ahead while a Mac has not answered, unless forced")
  func itDoesNotGoAheadUnlessForced() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    try writeEvents(1, as: "mac", in: home)
    try writeEvents(1, as: "laptop", in: home)
    let runs = Runs()
    let mac = controller(home, shared: "mac", runs: runs)
    mac.startCompaction()

    mac.finishCompaction()
    #expect(runs.isEmpty)
    #expect(mac.compactionMessage?.contains("laptop") == true)

    mac.finishCompaction(force: true)
    #expect(runs.count == 1)
    #expect(mac.compactionProgress == .idle)
  }

  @Test("a failed rebuild gives up the request, so every Mac writes again, and says why")
  func aFailedRebuildCancelsTheRequest() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let mac = controller(home, shared: "mac")
    mac.compaction = { throw EventLogError.ioFailure("disk full") }
    mac.startCompaction()

    mac.finishCompaction()

    #expect(try #require(mac.handshake).openRequest() == nil)
    #expect(mac.compactionProgress == .idle)
    #expect(mac.compactionMessage?.contains("disk full") == true)
    #expect(mac.compactionMessage?.contains("write again") == true)
  }

  @Test("a request another Mac left open can be cancelled from here, and this Mac writes again")
  func aLeftOverRequestCanBeCancelled() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let mac = CompactionHandshake(directory: home.url, deviceID: DeviceID("mac"))
    _ = try mac.request(id: "r0", at: ISO8601DateFormatter().string(from: Date()))
    let laptop = controller(home, shared: "laptop")
    laptop.refreshCompaction()
    #expect(laptop.compactionProgress == .pausedForOther(mac.token))

    laptop.cancelCompaction()

    #expect(try #require(laptop.handshake).openRequest() == nil)
    #expect(laptop.compactionProgress == .idle)
  }
}
