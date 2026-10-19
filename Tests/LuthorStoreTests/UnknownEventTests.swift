import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When the log holds an event type this build does not know")
struct UnknownEventTests {
  private let unknown = #"{"data":{"taskID":"t9"},"device":"phone","id":"e9","lamport":9,"type":"TaskSnoozed"}"#

  private func log(_ lines: [String], in dir: TemporaryDirectory) throws -> JSONLinesEventLog {
    try (lines.joined(separator: "\n") + "\n").write(
      to: dir.file("events.jsonl"), atomically: true, encoding: .utf8)
    return JSONLinesEventLog(fileURL: dir.file("events.jsonl"))
  }

  @Test("reading skips it and keeps the events around it")
  func readingSkipsIt() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let first = try EventLine.encode(captured("t1", "buy milk", id: "e1", lamport: 1))
    let last = try EventLine.encode(captured("t2", "pay rent", id: "e2", lamport: 2))
    let log = try log([first, unknown, last], in: dir)

    #expect(
      try log.readAll() == [captured("t1", "buy milk", id: "e1", lamport: 1), captured("t2", "pay rent", id: "e2", lamport: 2)])
  }

  @Test("the line stays in the file after more events are appended")
  func theLineStaysInTheFile() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = try log([unknown], in: dir)

    try log.append([captured("t1", "buy milk", id: "e1", lamport: 10)])

    let text = try String(contentsOf: dir.file("events.jsonl"), encoding: .utf8)
    #expect(text.hasPrefix(unknown + "\n"))
    #expect(try log.readAll() == [captured("t1", "buy milk", id: "e1", lamport: 10)])
  }

  @Test("a known type with a damaged payload is still an error")
  func aDamagedKnownLineIsStillAnError() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = try log([#"{"data":{},"device":"mac","id":"e1","lamport":1,"type":"TaskCaptured"}"#], in: dir)

    #expect(throws: EventLogError.unreadableLine(1)) { try log.readAll() }
  }

  @Test("a line with no type is still an error")
  func aLineWithNoTypeIsStillAnError() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = try log([#"{"data":{},"device":"mac","id":"e1","lamport":1}"#], in: dir)

    #expect(throws: EventLogError.unreadableLine(1)) { try log.readAll() }
  }

  @Test("decoding one directly says it is unknown, not damaged")
  func decodeIfKnownReturnsNil() throws {
    #expect(try EventLine.decodeIfKnown(unknown) == nil)
    #expect(throws: EventLogError.unreadableLine(0)) { try EventLine.decode(unknown) }
  }
}
