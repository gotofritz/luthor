import Foundation
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
