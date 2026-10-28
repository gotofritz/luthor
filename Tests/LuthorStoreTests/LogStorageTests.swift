import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("Given the places the log can live")
struct LogStorageTests {
  static let home = URL(fileURLWithPath: "/Users/me")
  static let folder = URL(fileURLWithPath: "/Users/me/Sync")

  @Test("Dropbox defaults to Dropbox/backups/Luthor in the home folder")
  func dropboxDefaultFolder() {
    #expect(LogStorage.defaultDropboxFolder(home: Self.home).path == "/Users/me/Dropbox/backups/Luthor")
  }

  @Test("Dropbox points the log at its folder")
  func dropboxSettings() {
    let storage = LogStorage(kind: .dropbox, dropboxFolder: Self.folder)

    #expect(storage.settings == ["LUTHOR_SYNC_DIR": "/Users/me/Sync"])
  }

  @Test("the Home Folder changes nothing, so the log stays at its default place")
  func homeFolderSettings() {
    #expect(LogStorage(kind: .homeFolder, dropboxFolder: Self.folder).settings.isEmpty)
  }

  @Test("a choice written down reads back the same")
  func choiceRoundTrips() {
    let storage = LogStorage(kind: .dropbox, dropboxFolder: Self.folder)

    let read = LogStorage(kindName: storage.kindName, dropboxFolderPath: storage.dropboxFolder.path, home: Self.home)

    #expect(read == storage)
  }

  @Test("the Home Folder reads back too, and keeps the Dropbox folder it had")
  func homeChoiceRoundTrips() {
    let storage = LogStorage(kind: .homeFolder, dropboxFolder: Self.folder)

    let read = LogStorage(kindName: storage.kindName, dropboxFolderPath: storage.dropboxFolder.path, home: Self.home)

    #expect(read == storage)
  }

  @Test("no choice written down reads as unset", arguments: [nil, "", "somewhere else"])
  func unsetChoice(kindName: String?) {
    #expect(LogStorage(kindName: kindName, dropboxFolderPath: "/d", home: Self.home) == nil)
  }

  @Test("Dropbox without a written folder falls back to the default one")
  func dropboxWithoutFolder() {
    let read = LogStorage(kindName: "dropbox", dropboxFolderPath: nil, home: Self.home)

    #expect(read?.dropboxFolder == LogStorage.defaultDropboxFolder(home: Self.home))
  }
}

@Suite("When a place for the log is taken into use")
struct LogStoragePrepareTests {
  private func dropbox(in home: TemporaryDirectory) -> LogStorage {
    LogStorage(kind: .dropbox, dropboxFolder: LogStorage.defaultDropboxFolder(home: home.url))
  }

  @Test("Dropbox creates its folder and the ones above it")
  func dropboxCreatesItsFolder() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let storage = dropbox(in: home)

    try storage.prepare(home: home.url, deviceID: DeviceID("desk"))

    var isDirectory: ObjCBool = false
    #expect(FileManager.default.fileExists(atPath: storage.dropboxFolder.path, isDirectory: &isDirectory))
    #expect(isDirectory.boolValue)
  }

  @Test("Dropbox copies the Home Folder log in as this device's file, and leaves the original")
  func dropboxCopiesTheHomeLog() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let homeLog = JSONLinesEventLog(fileURL: home.file(".luthor/events.jsonl"))
    try homeLog.append([captured("t1", "buy milk")])
    let storage = dropbox(in: home)

    try storage.prepare(home: home.url, deviceID: DeviceID("desk"))

    let copy = JSONLinesEventLog(fileURL: storage.dropboxFolder.appendingPathComponent("events-desk.jsonl"))
    #expect(try copy.readAll() == [captured("t1", "buy milk")])
    #expect(try homeLog.readAll() == [captured("t1", "buy milk")])
  }

  @Test("Dropbox never overwrites a file of this device that is already there")
  func dropboxKeepsAnExistingDeviceFile() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    try JSONLinesEventLog(fileURL: home.file(".luthor/events.jsonl")).append([captured("t1", "old")])
    let storage = dropbox(in: home)
    let existing = DeviceFilesEventLog(directory: storage.dropboxFolder, deviceID: DeviceID("desk"))
    try existing.append([captured("t2", "kept", device: "desk")])

    try storage.prepare(home: home.url, deviceID: DeviceID("desk"))

    #expect(try existing.readAll() == [captured("t2", "kept", device: "desk")])
  }

  @Test("the Home Folder creates nothing")
  func homeFolderCreatesNothing() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let storage = LogStorage(kind: .homeFolder, dropboxFolder: LogStorage.defaultDropboxFolder(home: home.url))

    try storage.prepare(home: home.url, deviceID: DeviceID("desk"))

    #expect(try FileManager.default.contentsOfDirectory(atPath: home.url.path).isEmpty)
  }

  @Test("a folder that cannot be made is an error")
  func unmakeableFolderIsAnError() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    try "a file".write(to: home.file("Dropbox"), atomically: true, encoding: .utf8)

    #expect(throws: EventLogError.self) {
      try dropbox(in: home).prepare(home: home.url, deviceID: DeviceID("desk"))
    }
  }
}

@Suite("When the folder of the log is checked")
struct LogStorageFolderStatusTests {
  private func storage(_ folder: URL) -> LogStorage { LogStorage(kind: .dropbox, dropboxFolder: folder) }

  private func makeDropboxRoot(in home: TemporaryDirectory) throws -> URL {
    let root = home.file("Dropbox")
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent(".dropbox"), withIntermediateDirectories: true)
    return root
  }

  @Test("a folder inside a folder Dropbox marks as its own is synced, and names that Dropbox")
  func insideDropbox() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let root = try makeDropboxRoot(in: home)
    let folder = root.appendingPathComponent("backups/Luthor")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    #expect(storage(folder).folderStatus() == .inDropbox(root: URL(fileURLWithPath: root.path, isDirectory: true)))
  }

  @Test("a folder with no Dropbox above it is only a local folder")
  func notInDropbox() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let folder = home.file("Dropbox/backups/Luthor")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    #expect(storage(folder).folderStatus() == .notInDropbox)
  }

  @Test("a folder that is gone is reported missing, even inside Dropbox")
  func missing() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let root = try makeDropboxRoot(in: home)

    #expect(storage(root.appendingPathComponent("backups/Luthor")).folderStatus() == .missing)
  }

  @Test("a file where the folder should be is reported missing")
  func fileIsNotAFolder() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    try "a file".write(to: home.file("Luthor"), atomically: true, encoding: .utf8)

    #expect(storage(home.file("Luthor")).folderStatus() == .missing)
  }

  @Test("the Home Folder has no folder to check")
  func homeFolderIsLocalOnly() {
    let storage = LogStorage(kind: .homeFolder, dropboxFolder: URL(fileURLWithPath: "/nowhere"))

    #expect(storage.folderStatus() == .localOnly)
  }
}
