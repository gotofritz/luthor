import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a duplicate or delete event is written to the log")
struct StructureLineTests {
  @Test("a TaskDuplicated names the task copied, the copy and the day")
  func taskDuplicatedNamesTheTasksAndTheDay() throws {
    let line = try EventLine.encode(duplicated("t1", as: "t2", on: "2026-10-19", id: "e1", lamport: 1))

    #expect(
      line
        == #"{"data":{"copy":"t2","createdOn":"2026-10-19","source":"t1"},"device":"mac","id":"e1","lamport":1,"type":"TaskDuplicated"}"#
    )
  }

  @Test("a TaskDuplicated without a day has no createdOn field")
  func taskDuplicatedWithoutADayHasNoCreatedOn() throws {
    let line = try EventLine.encode(duplicated("t1", as: "t2", id: "e2", lamport: 2))

    #expect(
      line == #"{"data":{"copy":"t2","source":"t1"},"device":"mac","id":"e2","lamport":2,"type":"TaskDuplicated"}"#)
  }

  @Test("a TaskDeleted names what it deletes, a task or a project")
  func deleteNamesWhatItDeletes() throws {
    let taskLine = try EventLine.encode(taskDeleted("t1", id: "e3", lamport: 3))
    let projectLine = try EventLine.encode(projectDeleted("p1", id: "e4", lamport: 4))

    #expect(taskLine == #"{"data":{"taskID":"t1"},"device":"mac","id":"e3","lamport":3,"type":"TaskDeleted"}"#)
    #expect(projectLine == #"{"data":{"taskID":"p1"},"device":"mac","id":"e4","lamport":4,"type":"TaskDeleted"}"#)
  }

  @Test("turning a task into a project is a TaskKindChanged")
  func promoteIsATaskKindChanged() throws {
    let line = try EventLine.encode(promoted("t1", id: "e5", lamport: 5))

    #expect(
      line
        == #"{"data":{"kind":"parallel","taskID":"t1"},"device":"mac","id":"e5","lamport":5,"type":"TaskKindChanged"}"#
    )
  }

  @Test("turning a project into a task is a TaskKindChanged with no kind")
  func demoteIsATaskKindChangedWithNoKind() throws {
    let line = try EventLine.encode(demoted("p1", id: "e6", lamport: 6))

    #expect(line == #"{"data":{"taskID":"p1"},"device":"mac","id":"e6","lamport":6,"type":"TaskKindChanged"}"#)
  }

  @Test(
    "each decodes back to the same event",
    arguments: [
      demoted("p1"),
      duplicated("t1", as: "t2", on: "2026-10-19"),
      duplicated("t1", as: "t2"),
      taskDeleted("t1"),
      projectDeleted("p1"),
      promoted("t1"),
    ])
  func structureLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}

@Suite("When a ChildrenOrdered event is written to the log")
struct ChildrenOrderedLineTests {
  @Test("it names the project and the children in order")
  func namesTheProjectAndTheChildren() throws {
    let line = try EventLine.encode(childrenOrdered("p1", ["t2", "t1"], id: "e1", lamport: 1))

    #expect(
      line
        == #"{"data":{"parentID":"p1","taskIDs":["t2","t1"]},"device":"mac","id":"e1","lamport":1,"type":"ChildrenOrdered"}"#
    )
  }

  @Test("it reads back the same")
  func readsBackTheSame() throws {
    let event = childrenOrdered("p1", ["t2", "t1"], id: "e1", lamport: 1)

    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}
