import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite struct FileChangeMonitorTests {
  @Test func untouchedFileIsUnchanged() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let file = dir.file("events.jsonl")
    try JSONLinesEventLog(fileURL: file).append([captured("t1", "buy milk")])
    var monitor = FileChangeMonitor(fileURL: file)

    #expect(monitor.poll() == false)
  }

  @Test func appendIsReportedOnce() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = JSONLinesEventLog(fileURL: dir.file("events.jsonl"))
    try log.append([captured("t1", "buy milk")])
    var monitor = FileChangeMonitor(fileURL: log.fileURL)

    try log.append([completed("t1")])

    #expect(monitor.poll() == true)
    #expect(monitor.poll() == false)
  }

  @Test func fileCreatedAfterStartIsAChange() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = JSONLinesEventLog(fileURL: dir.file("events.jsonl"))
    var monitor = FileChangeMonitor(fileURL: log.fileURL)
    #expect(monitor.poll() == false)

    try log.append([captured("t1", "buy milk")])

    #expect(monitor.poll() == true)
  }

  @Test func deletedFileIsAChange() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let file = dir.file("events.jsonl")
    try JSONLinesEventLog(fileURL: file).append([captured("t1", "buy milk")])
    var monitor = FileChangeMonitor(fileURL: file)

    try FileManager.default.removeItem(at: file)

    #expect(monitor.poll() == true)
  }
}

@Suite("Given a folder of device logs")
struct FolderChangeMonitorTests {
  @Test("an untouched folder is unchanged")
  func untouchedFolderIsUnchanged() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    try DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac")).append([captured("t1", "buy milk")])
    var monitor = FileChangeMonitor(directoryURL: dir.url)

    #expect(monitor.poll() == false)
  }

  @Test("an append to a device file is reported once")
  func appendIsReportedOnce() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac"))
    try log.append([captured("t1", "buy milk")])
    var monitor = FileChangeMonitor(directoryURL: dir.url)

    try log.append([completed("t1")])

    #expect(monitor.poll() == true)
    #expect(monitor.poll() == false)
  }

  @Test("a device file that appears later is a change")
  func newDeviceFileIsAChange() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    try DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac")).append([captured("t1", "buy milk")])
    var monitor = FileChangeMonitor(directoryURL: dir.url)

    try DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("air")).append([captured("t2", "call mum")])

    #expect(monitor.poll() == true)
  }

  @Test("a compaction request or answer in the folder is a change")
  func compactionFilesAreAChange() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    var monitor = FileChangeMonitor(directoryURL: dir.url)

    _ = try CompactionHandshake(directory: dir.url, deviceID: DeviceID("mac")).request(id: "r1", at: ISO8601DateFormatter().string(from: Date()))

    #expect(monitor.poll() == true)
  }

  @Test("a folder created after the monitor is a change")
  func folderCreatedLaterIsAChange() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let folder = dir.file("Luthor")
    var monitor = FileChangeMonitor(directoryURL: folder)
    #expect(monitor.poll() == false)

    try DeviceFilesEventLog(directory: folder, deviceID: DeviceID("mac")).append([captured("t1", "buy milk")])

    #expect(monitor.poll() == true)
  }

  @Test("files that are not device logs are not a change")
  func otherFilesAreNotAChange() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    var monitor = FileChangeMonitor(directoryURL: dir.url)

    try "hello".write(to: dir.file("notes.txt"), atomically: true, encoding: .utf8)

    #expect(monitor.poll() == false)
  }
}
