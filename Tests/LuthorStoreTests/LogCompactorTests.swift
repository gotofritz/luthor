import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When the log is compacted")
struct LogCompactorTests {
  private let manyEdits: [EventEnvelope] = [
    captured("t1", "milk", id: "e1", lamport: 1),
    renamed("t1", to: "buy milk", id: "e2", lamport: 2),
    renamed("t1", to: "buy oat milk", id: "e3", lamport: 3),
    renamed("t1", to: "buy oat milk today", id: "e4", lamport: 4),
    settingChanged(.themeAccent, to: "alpine", view: "default", id: "e5", lamport: 5),
  ]

  private func configuration(logAt file: URL) -> LuthorConfiguration {
    LuthorConfiguration(environment: ["LUTHOR_LOG": file.path], home: file.deletingLastPathComponent())
  }

  @Test("the library is the same afterwards, in fewer events")
  func theLibraryIsKept() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let config = configuration(logAt: dir.file("events.jsonl"))
    try config.makeEventLog().append(manyEdits)
    let before = LibraryState.replay(try config.makeEventLog().readAll()).export()

    let result = try LogCompactor.compact(configuration: config, ids: SequentialIDs(), stamp: "20261019-1200")

    let after = try config.makeEventLog().readAll()
    #expect(LibraryState.replay(after).export() == before)
    #expect(result.eventsBefore == 5)
    #expect(result.eventsAfter == after.count)
    #expect(after.count < 5)
  }

  @Test("the old log and a YAML copy are kept in a backup folder")
  func theOldLogIsBackedUp() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let config = configuration(logAt: dir.file("events.jsonl"))
    try config.makeEventLog().append(manyEdits)
    let original = try String(contentsOf: dir.file("events.jsonl"), encoding: .utf8)

    let result = try LogCompactor.compact(configuration: config, ids: SequentialIDs(), stamp: "20261019-1200")

    #expect(result.backupFolder.lastPathComponent == "compact-20261019-1200")
    let copy = try String(contentsOf: result.backupFolder.appendingPathComponent("events.jsonl"), encoding: .utf8)
    #expect(copy == original)
    let yaml = try String(contentsOf: result.backupFolder.appendingPathComponent("library.yml"), encoding: .utf8)
    #expect(yaml.contains("buy oat milk today"))
  }

  @Test("in a shared folder every device's file is replaced by this device's one")
  func aSharedFolderEndsWithOneFile() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let config = LuthorConfiguration(
      environment: ["LUTHOR_SYNC_DIR": dir.url.path, "LUTHOR_DEVICE_ID": "mac"], home: dir.url)
    let other = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("phone"))
    try other.append([captured("t2", "call mum", id: "p1", device: "phone", lamport: 1)])
    try config.makeEventLog().append(manyEdits)

    let result = try LogCompactor.compact(configuration: config, ids: SequentialIDs(), stamp: "s")

    let names = try FileManager.default.contentsOfDirectory(atPath: dir.url.path)
      .filter(DeviceFilesEventLog.isDeviceLog(named:))
    #expect(names == ["events-mac.jsonl"])
    #expect(LibraryState.replay(try config.makeEventLog().readAll()).export().items.count == 2)
    let kept = try FileManager.default.contentsOfDirectory(atPath: result.backupFolder.path)
    #expect(kept.contains("events-phone.jsonl") && kept.contains("events-mac.jsonl"))
  }

  @Test("an empty library leaves an empty log")
  func anEmptyLibraryLeavesAnEmptyLog() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let config = configuration(logAt: dir.file("events.jsonl"))

    let result = try LogCompactor.compact(configuration: config, ids: SequentialIDs(), stamp: "s")

    #expect(result.eventsAfter == 0)
    #expect(try config.makeEventLog().readAll().isEmpty)
  }

  @Test("an unreadable log is left as it is and nothing is backed up")
  func anUnreadableLogIsLeftAlone() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    try "garbage\n".write(to: dir.file("events.jsonl"), atomically: true, encoding: .utf8)
    let config = configuration(logAt: dir.file("events.jsonl"))

    #expect(throws: EventLogError.unreadableLine(1)) {
      try LogCompactor.compact(configuration: config, ids: SequentialIDs(), stamp: "s")
    }
    #expect(try String(contentsOf: dir.file("events.jsonl"), encoding: .utf8) == "garbage\n")
    #expect(!FileManager.default.fileExists(atPath: dir.file("backups").path))
  }
}
