import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

private func makeLogs(_ dir: TemporaryDirectory) -> (mac: DeviceFilesEventLog, air: DeviceFilesEventLog) {
  (
    DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac")),
    DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("air"))
  )
}

@Suite("Given a log read once")
struct IncrementalReadTests {
  @Test("reading again gives only the events appended since")
  func onlyTheNewEvents() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let (mac, air) = makeLogs(dir)
    try mac.append([captured("t1", "buy milk", device: "mac")])
    let cursor = try (mac.readReportingProblems().cursor).unwrap()
    let fresh = captured("t2", "call mum", device: "air", lamport: 2)
    try air.append([fresh])

    let increment = try (mac.readIncrement(since: cursor)).unwrap()

    #expect(increment.events == [fresh])
    #expect(increment.problems.isEmpty)
  }

  @Test("the cursor it gives moves on, so a third read finds nothing")
  func theCursorMovesOn() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let (mac, air) = makeLogs(dir)
    try mac.append([captured("t1", "buy milk", device: "mac")])
    let cursor = try (mac.readReportingProblems().cursor).unwrap()
    try air.append([captured("t2", "call mum", device: "air", lamport: 2)])
    let second = try (mac.readIncrement(since: cursor)).unwrap()

    let third = try (mac.readIncrement(since: (second.cursor).unwrap())).unwrap()

    #expect(third.events.isEmpty)
  }

  @Test("a file that shrank cannot be read on from")
  func shrunkFileIsNotIncremental() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let (mac, air) = makeLogs(dir)
    try air.append([captured("t2", "call mum", device: "air"), captured("t3", "pay rent", device: "air")])
    let cursor = try (mac.readReportingProblems().cursor).unwrap()

    try Data().write(to: dir.file("events-air.jsonl"))

    #expect(try mac.readIncrement(since: cursor) == nil)
  }

  @Test("a file rewritten to something longer cannot be read on from")
  func rewrittenFileIsNotIncremental() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let (mac, air) = makeLogs(dir)
    try air.append([captured("t2", "call mum", device: "air")])
    let cursor = try (mac.readReportingProblems().cursor).unwrap()

    let other = try EventLine.encode(captured("zz", "something else entirely, and longer", device: "air"))
    try (other + "\n" + other + "\n").write(to: dir.file("events-air.jsonl"), atomically: true, encoding: .utf8)

    #expect(try mac.readIncrement(since: cursor) == nil)
  }

  @Test("a file that went away cannot be read on from")
  func removedFileIsNotIncremental() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let (mac, air) = makeLogs(dir)
    try air.append([captured("t2", "call mum", device: "air")])
    let cursor = try (mac.readReportingProblems().cursor).unwrap()

    try FileManager.default.removeItem(at: dir.file("events-air.jsonl"))

    #expect(try mac.readIncrement(since: cursor) == nil)
  }

  @Test("a line another device has not finished syncing waits until it is whole")
  func unfinishedLineWaits() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let (mac, _) = makeLogs(dir)
    let cursor = try (mac.readReportingProblems().cursor).unwrap()
    let line = try EventLine.encode(captured("t2", "call mum", device: "air"))
    try Data(line.utf8.prefix(20)).write(to: dir.file("events-air.jsonl"))

    let partial = try (mac.readIncrement(since: cursor)).unwrap()
    try Data((line + "\n").utf8).write(to: dir.file("events-air.jsonl"))
    let whole = try (mac.readIncrement(since: (partial.cursor).unwrap())).unwrap()

    #expect(partial.events.isEmpty)
    #expect(partial.problems.isEmpty)
    #expect(whole.events.map(\.id.rawValue) == [captured("t2", "call mum", device: "air").id.rawValue])
  }

  @Test("a damaged line is reported with its line number in the whole file")
  func damagedLineKeepsItsNumber() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let (mac, air) = makeLogs(dir)
    try air.append([captured("t2", "call mum", device: "air")])
    let cursor = try (mac.readReportingProblems().cursor).unwrap()
    let good = try EventLine.encode(captured("t3", "pay rent", device: "air", lamport: 2))
    let handle = try FileHandle(forWritingTo: dir.file("events-air.jsonl"))
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(("not json\n" + good + "\n").utf8))
    try handle.close()

    let increment = try (mac.readIncrement(since: cursor)).unwrap()

    #expect(increment.problems == [LogProblem(file: "events-air.jsonl", line: 2)])
    #expect(increment.events.count == 1)
  }

  @Test("a log that cannot tell what changed has no cursor to give")
  func plainLogsHaveNoCursor() throws {
    let log = InMemoryEventLog([captured("t1", "buy milk")])

    #expect(try log.readReportingProblems().cursor == nil)
  }
}

private struct MissingValue: Error {}

extension Optional {
  fileprivate func unwrap() throws -> Wrapped {
    guard let self else { throw MissingValue() }
    return self
  }
}
