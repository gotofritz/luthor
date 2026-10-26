import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a log has a damaged line")
struct DamagedLineTests {
  private func tornLog(in dir: TemporaryDirectory) throws -> JSONLinesEventLog {
    let text = try EventLine.encode(captured("t1", "buy milk")) + "\n" + #"{"data":{"taskID":"t2","ti"#
    try text.write(to: dir.file("events.jsonl"), atomically: true, encoding: .utf8)
    return JSONLinesEventLog(fileURL: dir.file("events.jsonl"))
  }

  @Test("appending after a torn last line starts on a fresh line")
  func appendStartsOnAFreshLine() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = try tornLog(in: dir)

    try log.append([captured("t3", "call mum")])

    let reading = try log.readReportingProblems()
    #expect(reading.events == [captured("t1", "buy milk"), captured("t3", "call mum")])
    #expect(reading.problems == [LogProblem(file: "events.jsonl", line: 2)])
  }

  @Test("appending to a file that ends in a newline adds no blank line")
  func appendAddsNoBlankLine() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = JSONLinesEventLog(fileURL: dir.file("events.jsonl"))

    try log.append([captured("t1", "a")])
    try log.append([captured("t2", "b")])

    let text = try String(contentsOf: dir.file("events.jsonl"), encoding: .utf8)
    #expect(text.split(separator: "\n", omittingEmptySubsequences: false).count == 3)
  }

  @Test("a bad line in the middle is reported with its number and the rest is read")
  func badLineInTheMiddleIsReported() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let text =
      try EventLine.encode(captured("t1", "a")) + "\ngarbage\n" + EventLine.encode(captured("t2", "b")) + "\n"
    try text.write(to: dir.file("events.jsonl"), atomically: true, encoding: .utf8)

    let reading = try JSONLinesEventLog(fileURL: dir.file("events.jsonl")).readReportingProblems()

    #expect(reading.events == [captured("t1", "a"), captured("t2", "b")])
    #expect(reading.problems == [LogProblem(file: "events.jsonl", line: 2)])
  }

  @Test("quarantining moves the bad lines aside and keeps every event")
  func quarantineMovesBadLinesAside() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = try tornLog(in: dir)
    try log.append([captured("t3", "call mum")])

    #expect(try log.quarantineUnreadableLines() == 1)

    let reading = try log.readReportingProblems()
    #expect(reading.events == [captured("t1", "buy milk"), captured("t3", "call mum")])
    #expect(reading.problems.isEmpty)
    let rejected = try String(contentsOf: dir.file("events.jsonl.rejected"), encoding: .utf8)
    #expect(rejected == #"{"data":{"taskID":"t2","ti"# + "\n")
  }

  @Test("quarantining a clean log changes nothing")
  func quarantineOfACleanLogChangesNothing() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = JSONLinesEventLog(fileURL: dir.file("events.jsonl"))
    try log.append([captured("t1", "a")])
    let before = try Data(contentsOf: dir.file("events.jsonl"))

    #expect(try log.quarantineUnreadableLines() == 0)
    #expect(try Data(contentsOf: dir.file("events.jsonl")) == before)
  }

  @Test("in a shared folder, another device's bad line is reported with its file and left alone")
  func otherDevicesBadLineIsReported() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let air = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("air"))
    try air.append([captured("t1", "a", device: "air")])
    let handle = try FileHandle(forWritingTo: dir.file("events-air.jsonl"))
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("garbage\n".utf8))
    try handle.close()
    let mac = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac"))
    let before = try Data(contentsOf: dir.file("events-air.jsonl"))

    let reading = try mac.readReportingProblems()

    #expect(reading.events == [captured("t1", "a", device: "air")])
    #expect(reading.problems == [LogProblem(file: "events-air.jsonl", line: 2)])
    #expect(try mac.quarantineUnreadableLines() == 0)
    #expect(try Data(contentsOf: dir.file("events-air.jsonl")) == before)
  }

  @Test("in a shared folder, a torn tail in the own file is repaired by quarantining")
  func ownTornTailIsQuarantined() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let mac = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac"))
    try mac.append([captured("t1", "a", device: "mac")])
    let handle = try FileHandle(forWritingTo: dir.file("events-mac.jsonl"))
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(#"{"data":"#.utf8))
    try handle.close()

    #expect(try mac.readReportingProblems().problems.count == 1)
    #expect(try mac.quarantineUnreadableLines() == 1)
    #expect(try mac.readReportingProblems().problems.isEmpty)
    #expect(try mac.readAll() == [captured("t1", "a", device: "mac")])
  }
}
