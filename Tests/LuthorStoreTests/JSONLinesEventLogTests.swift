import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite struct EventLineFormatTests {
  @Test func taskCapturedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(captured("t1", "buy \"milk\"", id: "e1", device: "mac", lamport: 1))

    #expect(
      line
        == #"{"data":{"taskID":"t1","title":"buy \"milk\""},"device":"mac","id":"e1","lamport":1,"type":"TaskCaptured"}"#
    )
  }

  @Test func taskCompletedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(completed("t1", id: "e2", device: "air", lamport: 2))

    #expect(line == #"{"data":{"taskID":"t1"},"device":"air","id":"e2","lamport":2,"type":"TaskCompleted"}"#)
  }

  @Test(arguments: [captured("t1", "buy milk"), completed("t1")])
  func lineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}

@Suite struct JSONLinesEventLogTests {
  @Test func missingFileReadsAsEmptyLog() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }

    let log = JSONLinesEventLog(fileURL: dir.file("events.jsonl"))

    #expect(try log.readAll() == [])
  }

  @Test func appendedEventsReadBackInAppendOrder() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = JSONLinesEventLog(fileURL: dir.file("nested/dir/events.jsonl"))

    try log.append([captured("t1", "buy milk", lamport: 1)])
    try log.append([captured("t2", "call mum", lamport: 2), completed("t1", lamport: 3)])

    #expect(
      try log.readAll() == [
        captured("t1", "buy milk", lamport: 1),
        captured("t2", "call mum", lamport: 2),
        completed("t1", lamport: 3),
      ])
  }

  @Test func appendKeepsExistingBytesUntouched() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let file = dir.file("events.jsonl")
    let log = JSONLinesEventLog(fileURL: file)
    try log.append([captured("t1", "buy milk")])
    let before = try Data(contentsOf: file)

    try log.append([completed("t1")])

    let after = try Data(contentsOf: file)
    #expect(after.prefix(before.count) == before)
    #expect(after.last == UInt8(ascii: "\n"))
  }

  @Test func blankLinesAreIgnored() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let file = dir.file("events.jsonl")
    let line = try EventLine.encode(captured("t1", "buy milk"))
    try Data("\n\(line)\n\n".utf8).write(to: file)

    #expect(try JSONLinesEventLog(fileURL: file).readAll() == [captured("t1", "buy milk")])
  }

  @Test(arguments: [
    "not json",
    #"{"data":{},"device":"mac","id":"e9","lamport":1,"type":"TaskExploded"}"#,
    #"{"data":{"taskID":"t1"},"device":"mac","id":"e9","type":"TaskCompleted"}"#,
  ])
  func unreadableLineFailsWithItsLineNumber(badLine: String) throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let file = dir.file("events.jsonl")
    let good = try EventLine.encode(captured("t1", "buy milk"))
    try Data("\(good)\n\(badLine)\n".utf8).write(to: file)

    #expect(throws: EventLogError.unreadableLine(2)) {
      try JSONLinesEventLog(fileURL: file).readAll()
    }
  }
}
