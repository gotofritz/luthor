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
@Suite("When the log is compacted from Settings")
struct CompactLogTests {
  private func controller(_ home: TemporaryDirectory) -> StorageController {
    StorageController(saved: nil, home: home.url, deviceID: DeviceID("desk"), save: { _ in })
  }

  @Test("it reports the backup and the events before and after")
  func itReportsTheResult() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let controller = controller(home)
    let backup = home.file("backups/compact-s")
    controller.compaction = { LogCompaction(eventsBefore: 900, eventsAfter: 40, backupFolder: backup) }

    controller.compactLog()

    #expect(controller.compactionMessage?.contains("900") == true)
    #expect(controller.compactionMessage?.contains("40") == true)
    #expect(controller.compactionMessage?.contains(backup.path) == true)
  }

  @Test("a failure is reported and nothing else happens")
  func aFailureIsReported() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let controller = controller(home)
    controller.compaction = { throw .ioFailure("disk full") }

    controller.compactLog()

    #expect(controller.compactionMessage?.contains("disk full") == true)
  }

  @Test("with no compaction wired in, it does nothing")
  func nothingWithoutACompaction() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let controller = controller(home)

    controller.compactLog()

    #expect(controller.compactionMessage == nil)
  }
}
