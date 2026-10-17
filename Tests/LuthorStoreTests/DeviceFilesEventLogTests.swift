import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("Given a folder shared by several devices")
struct DeviceFilesEventLogTests {
  @Test("a device appends to its own file only")
  func deviceAppendsToItsOwnFile() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }

    try DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac")).append([captured("t1", "buy milk")])

    let names = try FileManager.default.contentsOfDirectory(atPath: dir.url.path)
    #expect(names == ["events-mac.jsonl"])
  }

  @Test("a device never rewrites another device's file")
  func deviceLeavesOtherFilesAlone() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let mac = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac"))
    let air = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("air"))
    try mac.append([captured("t1", "buy milk", device: "mac")])
    let before = try Data(contentsOf: dir.file("events-mac.jsonl"))

    try air.append([captured("t2", "call mum", device: "air")])

    #expect(try Data(contentsOf: dir.file("events-mac.jsonl")) == before)
  }

  @Test("reading merges the files of every device")
  func readingMergesEveryDevice() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let mac = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac"))
    let air = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("air"))
    let first = captured("t1", "buy milk", device: "mac")
    let second = captured("t2", "call mum", device: "air")
    try mac.append([first])
    try air.append([second])

    #expect(try mac.readAll() == [second, first])
    #expect(try air.readAll() == [second, first])
  }

  @Test("a folder that does not exist yet is an empty log")
  func missingFolderIsEmpty() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }

    let log = DeviceFilesEventLog(directory: dir.file("Luthor"), deviceID: DeviceID("mac"))

    #expect(try log.readAll().isEmpty)
  }

  @Test("files that are not device logs are ignored")
  func otherFilesAreIgnored() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac"))
    try log.append([captured("t1", "buy milk")])
    try "not an event\n".write(to: dir.file("notes.txt"), atomically: true, encoding: .utf8)
    try "not an event\n".write(to: dir.file("events.jsonl"), atomically: true, encoding: .utf8)

    #expect(try log.readAll() == [captured("t1", "buy milk")])
  }

  @Test("a device ID that is not safe in a file name is made safe")
  func unsafeDeviceIDMakesASafeFileName() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }

    try DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("Fritz's MacBook/Pro"))
      .append([captured("t1", "buy milk")])

    let names = try FileManager.default.contentsOfDirectory(atPath: dir.url.path)
    #expect(names == ["events-Fritz-s-MacBook-Pro.jsonl"])
  }

  @Test("a conflict copy made by the sync service is read like any device file, and its events count once")
  func conflictCopyIsReadWithoutDuplicates() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac"))
    try log.append([captured("t1", "buy milk")])
    try FileManager.default.copyItem(
      at: dir.file("events-mac.jsonl"), to: dir.file("events-mac (conflicted copy).jsonl"))

    let state = LibraryState.replay(try log.readAll())

    #expect(state.view(.default).openTasks.map(\.title) == ["buy milk"])
  }

  @Test("another device's half-synced last line is skipped until the rest arrives")
  func halfSyncedTailOfAnotherDeviceIsSkipped() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let air = captured("t2", "call mum", device: "air")
    let text = try EventLine.encode(air) + "\n" + #"{"data":{"taskID":"t3","ti"#
    try text.write(to: dir.file("events-air.jsonl"), atomically: true, encoding: .utf8)

    let events = try DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac")).readAll()

    #expect(events == [air])
  }

  @Test("a damaged line that is not the tail is an error, never skipped")
  func damagedLineOfAnotherDeviceIsAnError() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let text = "garbage\n" + (try EventLine.encode(captured("t2", "call mum", device: "air"))) + "\n"
    try text.write(to: dir.file("events-air.jsonl"), atomically: true, encoding: .utf8)
    let log = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac"))

    #expect(throws: EventLogError.unreadableLine(1)) { try log.readAll() }
  }

  @Test("a damaged tail in the device's own file is an error")
  func damagedTailOfOwnFileIsAnError() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let text = try EventLine.encode(captured("t1", "buy milk")) + "\n" + #"{"data":{"taskID"#
    try text.write(to: dir.file("events-mac.jsonl"), atomically: true, encoding: .utf8)
    let log = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac"))

    #expect(throws: EventLogError.unreadableLine(2)) { try log.readAll() }
  }
}
