import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a log holds hostile or extreme values")
struct HostileValueTests {
  @Test("a line with the highest Lamport counter is reported, not replayed")
  func overflowingLamportIsAProblem() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let hostile = try EventLine.encode(captured("t1", "buy milk", lamport: UInt64.max))
    let fine = try EventLine.encode(captured("t2", "call mum", lamport: EventLine.maxLamport))
    try (hostile + "\n" + fine + "\n").write(to: dir.file("events.jsonl"), atomically: true, encoding: .utf8)

    let reading = try JSONLinesEventLog(fileURL: dir.file("events.jsonl")).readReportingProblems()

    #expect(reading.events == [captured("t2", "call mum", lamport: EventLine.maxLamport)])
    #expect(reading.problems == [LogProblem(file: "events.jsonl", line: 1)])
  }

  @Test("a Lamport counter beyond 64 bits is reported")
  func hugeLamportIsAProblem() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let line = try EventLine.encode(captured("t1", "buy milk")).replacingOccurrences(
      of: #""lamport":1"#, with: #""lamport":99999999999999999999999"#)
    try (line + "\n").write(to: dir.file("events.jsonl"), atomically: true, encoding: .utf8)

    let reading = try JSONLinesEventLog(fileURL: dir.file("events.jsonl")).readReportingProblems()

    #expect(reading.events.isEmpty)
    #expect(reading.problems.count == 1)
  }

  @Test("commands after the highest accepted counter do not trap")
  func commandsAfterTheHighestCounter() throws {
    let log = [captured("t1", "buy milk", lamport: EventLine.maxLamport)]
    let commands = Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())

    let events = try commands.capture(title: "call mum", in: .default, log: log)

    #expect(events.first?.lamport == EventLine.maxLamport + 1)
  }

  @Test("a device's file refuses a line written for another device")
  func forgedDeviceIsAProblem() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let own = captured("t1", "buy milk", device: "air")
    let forged = captured("t2", "forged", device: "mac")
    let text = try EventLine.encode(own) + "\n" + EventLine.encode(forged) + "\n"
    try text.write(to: dir.file("events-air.jsonl"), atomically: true, encoding: .utf8)
    let log = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac"))

    let reading = try log.readReportingProblems()

    #expect(reading.events == [own])
    #expect(reading.problems == [LogProblem(file: "events-air.jsonl", line: 2)])
  }

  @Test("repair moves a forged line out of this device's own file")
  func repairMovesForgedLine() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let own = captured("t1", "buy milk", device: "mac")
    let forged = captured("t2", "forged", device: "air")
    let text = try EventLine.encode(own) + "\n" + EventLine.encode(forged) + "\n"
    try text.write(to: dir.file("events-mac.jsonl"), atomically: true, encoding: .utf8)
    let log = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac"))

    #expect(try log.quarantineUnreadableLines() == 1)
    #expect(try log.readReportingProblems().events == [own])
  }

  @Test("device IDs that sanitise to the same file name stay apart")
  func collidingDeviceIDsStayApart() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let slash = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("my/mac"))
    let space = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("my mac"))
    let first = captured("t1", "buy milk", device: "my/mac")
    let second = captured("t2", "call mum", device: "my mac")

    try slash.append([first])
    try space.append([second])

    let reading = try slash.readReportingProblems()
    #expect(reading.problems.isEmpty)
    #expect(Set(reading.events.map(\.deviceID)) == [DeviceID("my/mac"), DeviceID("my mac")])
    #expect(LibraryState.replay(reading.events).view(.default).openTasks.count == 2)
  }

  @Test("a file larger than the limit is refused, not read into memory")
  func oversizedFileIsRefused() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    try (try EventLine.encode(captured("t1", "buy milk")) + "\n")
      .write(to: dir.file("events.jsonl"), atomically: true, encoding: .utf8)
    let log = JSONLinesEventLog(fileURL: dir.file("events.jsonl"), maxBytes: 10)

    #expect(throws: EventLogError.self) { try log.readReportingProblems() }
    #expect(throws: EventLogError.self) { try log.quarantineUnreadableLines() }
  }
}
