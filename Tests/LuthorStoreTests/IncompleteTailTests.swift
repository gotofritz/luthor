import Foundation
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When the last line of a log is half written")
struct IncompleteTailTests {
  private func logWithHalfWrittenTail(in dir: TemporaryDirectory) throws -> JSONLinesEventLog {
    let text = try EventLine.encode(captured("t1", "buy milk")) + "\n" + #"{"data":{"taskID":"t2","ti"#
    try text.write(to: dir.file("events.jsonl"), atomically: true, encoding: .utf8)
    return JSONLinesEventLog(fileURL: dir.file("events.jsonl"))
  }

  @Test("reading is an error by default")
  func readingFailsByDefault() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = try logWithHalfWrittenTail(in: dir)

    #expect(throws: EventLogError.unreadableLine(2)) { try log.readAll() }
  }

  @Test("reading can skip it, and keeps the events before it")
  func readingCanSkipTheTail() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let log = try logWithHalfWrittenTail(in: dir)

    #expect(try log.readAll(skippingIncompleteTail: true) == [captured("t1", "buy milk")])
  }

  @Test("a damaged line that ends with a newline is never skipped")
  func completeDamagedLineIsNeverSkipped() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    try "garbage\n".write(to: dir.file("events.jsonl"), atomically: true, encoding: .utf8)
    let log = JSONLinesEventLog(fileURL: dir.file("events.jsonl"))

    #expect(throws: EventLogError.unreadableLine(1)) { try log.readAll(skippingIncompleteTail: true) }
  }
}
