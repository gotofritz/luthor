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
  @Test("a project is a TaskCaptured with a kind, as one sorted JSON object")
  func projectCreatedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(projectCreated("p1", "Move house", kind: .sequential, id: "e1", lamport: 1))

    #expect(
      line
        == #"{"data":{"kind":"sequential","taskID":"p1","title":"Move house","viewID":"default"},"device":"mac","id":"e1","lamport":1,"type":"TaskCaptured"}"#
    )
  }

  @Test("TaskMoved is one sorted JSON object")
  func taskMovedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(moved("t1", to: "p1", id: "e2", lamport: 2))

    #expect(
      line
        == #"{"data":{"parentID":"p1","taskID":"t1"},"device":"mac","id":"e2","lamport":2,"type":"TaskMoved"}"#
    )
  }

  @Test("completing a project is a TaskCompleted naming it")
  func projectCompletedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(projectCompleted("p1", id: "e3", lamport: 3))

    #expect(line == #"{"data":{"taskID":"p1"},"device":"mac","id":"e3","lamport":3,"type":"TaskCompleted"}"#)
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

  @Test("moving a project to a view is a TaskMovedToView naming it")
  func projectMovedToViewIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(projectMovedToView("p1", toView: "v1", id: "e4", lamport: 4))

    #expect(
      line == #"{"data":{"taskID":"p1","viewID":"v1"},"device":"mac","id":"e4","lamport":4,"type":"TaskMovedToView"}"#
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

  @Test("a TaskCaptured line for a task or a project written before views decodes into the default view")
  func preViewLinesDecodeIntoTheDefaultView() throws {
    let task =
      #"{"data":{"taskID":"t1","title":"buy milk"},"device":"mac","id":"e1","lamport":1,"type":"TaskCaptured"}"#
    let project =
      #"{"data":{"kind":"parallel","taskID":"p1","title":"Holiday"},"device":"mac","id":"e2","lamport":2,"type":"TaskCaptured"}"#

    #expect(try EventLine.decode(task) == captured("t1", "buy milk", id: "e1", lamport: 1))
    #expect(try EventLine.decode(project) == projectCreated("p1", "Holiday", id: "e2", lamport: 2))
  }
}

@Suite("When nesting events are written as lines")
struct NestingEventLineFormatTests {
  @Test("a TaskCaptured under a parent carries its parentID")
  func projectCreatedUnderAParentCarriesParentID() throws {
    let line = try EventLine.encode(projectCreated("p2", "Kitchen", under: "p1", id: "e1", lamport: 1))

    #expect(
      line
        == #"{"data":{"kind":"parallel","parentID":"p1","taskID":"p2","title":"Kitchen","viewID":"default"},"device":"mac","id":"e1","lamport":1,"type":"TaskCaptured"}"#
    )
  }

  @Test("nesting a project is a TaskMoved with a parent")
  func projectMovedToProjectIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(nested("p2", under: "p1", id: "e2", lamport: 2))

    #expect(
      line
        == #"{"data":{"parentID":"p1","taskID":"p2"},"device":"mac","id":"e2","lamport":2,"type":"TaskMoved"}"#
    )
  }

  @Test("a TaskMoved to the top has no parentID")
  func unnestingHasNoParentID() throws {
    let line = try EventLine.encode(nested("p2", under: nil, id: "e3", lamport: 3))

    #expect(line == #"{"data":{"taskID":"p2"},"device":"mac","id":"e3","lamport":3,"type":"TaskMoved"}"#)
  }

  @Test(
    "each decodes back to the same event",
    arguments: [projectCreated("p2", "Kitchen", under: "p1"), nested("p2", under: "p1"), nested("p2", under: nil)])
  func nestingLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}

@Suite("When a priority is written to the log")
struct PriorityLineTests {
  @Test("TaskPrioritized is one sorted JSON object")
  func taskPrioritizedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(prioritized("t1", as: .critical, id: "e4", lamport: 4))

    #expect(
      line == #"{"data":{"priority":"A","taskID":"t1"},"device":"mac","id":"e4","lamport":4,"type":"TaskPrioritized"}"#)
  }

  @Test("clearing a priority has no priority field")
  func clearingHasNoPriorityField() throws {
    let line = try EventLine.encode(prioritized("t1", as: nil, id: "e5", lamport: 5))

    #expect(line == #"{"data":{"taskID":"t1"},"device":"mac","id":"e5","lamport":5,"type":"TaskPrioritized"}"#)
  }

  @Test(
    "each decodes back to the same event",
    arguments: [
      prioritized("t1", as: .critical), prioritized("t1", as: .important), prioritized("t1", as: .optional),
      prioritized("t1", as: .someday), prioritized("t1", as: nil),
    ])
  func priorityLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}

@Suite("When an estimate is written to the log")
struct EstimateLineTests {
  @Test("TaskEstimated is one sorted JSON object")
  func taskEstimatedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(estimated("t1", as: 15, id: "e6", lamport: 6))

    #expect(
      line
        == #"{"data":{"minutes":15,"taskID":"t1"},"device":"mac","id":"e6","lamport":6,"type":"TaskEstimated"}"#)
  }

  @Test("clearing an estimate has no minutes field")
  func clearingHasNoMinutesField() throws {
    let line = try EventLine.encode(estimated("t1", as: nil, id: "e7", lamport: 7))

    #expect(line == #"{"data":{"taskID":"t1"},"device":"mac","id":"e7","lamport":7,"type":"TaskEstimated"}"#)
  }

  @Test(
    "each decodes back to the same event",
    arguments: [estimated("t1", as: 5), estimated("t1", as: 90), estimated("t1", as: nil)])
  func estimateLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}

@Suite("When a setting is written to the log")
struct SettingLineTests {
  @Test("a global SettingChanged is one sorted JSON object")
  func globalSettingChangedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(settingChanged(.bufferPercentage, to: "20", id: "e1", lamport: 1))

    #expect(
      line
        == #"{"data":{"key":"bufferPercentage","value":"20"},"device":"mac","id":"e1","lamport":1,"type":"SettingChanged"}"#
    )
  }

  @Test("an override for a view carries its viewID")
  func overrideCarriesViewID() throws {
    let line = try EventLine.encode(settingChanged(.bufferPercentage, to: "5", view: "work", id: "e2", lamport: 2))

    #expect(
      line
        == #"{"data":{"key":"bufferPercentage","value":"5","viewID":"work"},"device":"mac","id":"e2","lamport":2,"type":"SettingChanged"}"#
    )
  }

  @Test("clearing a setting has no value field")
  func clearingHasNoValueField() throws {
    let line = try EventLine.encode(settingChanged(.bufferPercentage, to: nil, id: "e3", lamport: 3))

    #expect(
      line
        == #"{"data":{"key":"bufferPercentage"},"device":"mac","id":"e3","lamport":3,"type":"SettingChanged"}"#
    )
  }

  @Test(
    "each decodes back to the same event",
    arguments: [
      settingChanged(.bufferPercentage, to: "20"), settingChanged(.bufferPercentage, to: "5", view: "work"),
      settingChanged(.defaultViewID, to: "work"), settingChanged(.bufferPercentage, to: nil),
    ])
  func settingLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }

  @Test("a key this build does not recognise decodes, and is ignored on replay")
  func unrecognisedKeyDecodesAndIsIgnoredOnReplay() throws {
    let line =
      #"{"data":{"key":"someFutureSetting","value":"1"},"device":"mac","id":"e9","lamport":9,"type":"SettingChanged"}"#

    let event = try EventLine.decode(line)

    guard case .settingChanged(let changed) = event.payload else {
      Issue.record("expected a SettingChanged")
      return
    }
    #expect(changed.key == "someFutureSetting")
    #expect(LibraryState.replay([event]).globalSettings.bufferPercentage == 40)
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

@Suite("When reopen events are written as lines")
struct ReopenEventLineFormatTests {
  @Test("TaskReopened is one sorted JSON object")
  func taskReopenedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(reopened("t1", id: "e1", lamport: 3))

    #expect(line == #"{"data":{"taskID":"t1"},"device":"mac","id":"e1","lamport":3,"type":"TaskReopened"}"#)
  }

  @Test("reopening a project is a TaskReopened naming it")
  func projectReopenedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(projectReopened("p1", id: "e2", lamport: 4))

    #expect(line == #"{"data":{"taskID":"p1"},"device":"mac","id":"e2","lamport":4,"type":"TaskReopened"}"#)
  }

  @Test(arguments: [reopened("t1"), projectReopened("p1")])
  func reopenLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}

@Suite("When card events are written as lines")
struct CardEventLineFormatTests {
  @Test("TaskNoted is one sorted JSON object")
  func taskNotedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(noted("t1", "oat", id: "e1", lamport: 3))

    #expect(line == #"{"data":{"notes":"oat","taskID":"t1"},"device":"mac","id":"e1","lamport":3,"type":"TaskNoted"}"#)
  }

  @Test("TaskKindChanged is one sorted JSON object")
  func projectKindChangedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(kindChanged("p1", to: .sequential, id: "e2", lamport: 3))

    #expect(
      line
        == #"{"data":{"kind":"sequential","taskID":"p1"},"device":"mac","id":"e2","lamport":3,"type":"TaskKindChanged"}"#
    )
  }

  @Test(
    arguments: [
      renamed("t1", to: "buy milk"), noted("t1", "oat"), noted("t1", nil), projectRenamed("p1", to: "Summer"),
      projectNoted("p1", "https://example.com"), projectNoted("p1", nil), kindChanged("p1", to: .sequential),
    ])
  func cardLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}
