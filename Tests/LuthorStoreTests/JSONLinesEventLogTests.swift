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
        == #"{"data":{"taskID":"t1","title":"buy \"milk\"","viewID":"default"},"device":"mac","id":"e1","lamport":1,"type":"TaskCaptured"}"#
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

@Suite("When project events are written as lines")
struct ProjectEventLineFormatTests {
  @Test("ProjectCreated is one sorted JSON object")
  func projectCreatedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(projectCreated("p1", "Move house", kind: .sequential, id: "e1", lamport: 1))

    #expect(
      line
        == #"{"data":{"kind":"sequential","projectID":"p1","title":"Move house","viewID":"default"},"device":"mac","id":"e1","lamport":1,"type":"ProjectCreated"}"#
    )
  }

  @Test("TaskMovedToProject is one sorted JSON object")
  func taskMovedToProjectIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(moved("t1", to: "p1", id: "e2", lamport: 2))

    #expect(
      line
        == #"{"data":{"projectID":"p1","taskID":"t1"},"device":"mac","id":"e2","lamport":2,"type":"TaskMovedToProject"}"#
    )
  }

  @Test("ProjectCompleted is one sorted JSON object")
  func projectCompletedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(projectCompleted("p1", id: "e3", lamport: 3))

    #expect(line == #"{"data":{"projectID":"p1"},"device":"mac","id":"e3","lamport":3,"type":"ProjectCompleted"}"#)
  }

  @Test(arguments: [projectCreated("p1", "Holiday"), moved("t1", to: "p1"), projectCompleted("p1")])
  func projectLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}

@Suite("When view events are written as lines")
struct ViewEventLineFormatTests {
  @Test("ViewCreated is one sorted JSON object")
  func viewCreatedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(viewCreated("v1", "Work", id: "e1", lamport: 1))

    #expect(
      line == #"{"data":{"name":"Work","viewID":"v1"},"device":"mac","id":"e1","lamport":1,"type":"ViewCreated"}"#)
  }

  @Test("ViewRenamed is one sorted JSON object")
  func viewRenamedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(viewRenamed("v1", to: "Office", id: "e2", lamport: 2))

    #expect(
      line == #"{"data":{"name":"Office","viewID":"v1"},"device":"mac","id":"e2","lamport":2,"type":"ViewRenamed"}"#)
  }

  @Test("TaskMovedToView is one sorted JSON object")
  func taskMovedToViewIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(movedToView("t1", toView: "v1", id: "e3", lamport: 3))

    #expect(
      line == #"{"data":{"taskID":"t1","viewID":"v1"},"device":"mac","id":"e3","lamport":3,"type":"TaskMovedToView"}"#)
  }

  @Test("ProjectMovedToView is one sorted JSON object")
  func projectMovedToViewIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(projectMovedToView("p1", toView: "v1", id: "e4", lamport: 4))

    #expect(
      line
        == #"{"data":{"projectID":"p1","viewID":"v1"},"device":"mac","id":"e4","lamport":4,"type":"ProjectMovedToView"}"#
    )
  }

  @Test(
    "each decodes back to the same event",
    arguments: [
      viewCreated("v1", "Work"), viewRenamed("v1", to: "Office"), movedToView("t1", toView: "v1"),
      projectMovedToView("p1", toView: "v1"), captured("t1", "a", view: "v1"), projectCreated("p1", "b", view: "v1"),
    ])
  func viewLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }

  @Test("a TaskCaptured or ProjectCreated line written before views decodes into the default view")
  func preViewLinesDecodeIntoTheDefaultView() throws {
    let task =
      #"{"data":{"taskID":"t1","title":"buy milk"},"device":"mac","id":"e1","lamport":1,"type":"TaskCaptured"}"#
    let project =
      #"{"data":{"kind":"parallel","projectID":"p1","title":"Holiday"},"device":"mac","id":"e2","lamport":2,"type":"ProjectCreated"}"#

    #expect(try EventLine.decode(task) == captured("t1", "buy milk", id: "e1", lamport: 1))
    #expect(try EventLine.decode(project) == projectCreated("p1", "Holiday", id: "e2", lamport: 2))
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
