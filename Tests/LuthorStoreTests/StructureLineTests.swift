import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a duplicate, delete or promote event is written to the log")
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

  @Test("a TaskDeleted, a ProjectDeleted and a TaskPromotedToProject name what they act on")
  func deleteAndPromoteNameWhatTheyActOn() throws {
    let taskLine = try EventLine.encode(taskDeleted("t1", id: "e3", lamport: 3))
    let projectLine = try EventLine.encode(projectDeleted("p1", id: "e4", lamport: 4))
    let promotedLine = try EventLine.encode(promoted("t1", to: "p1", id: "e5", lamport: 5))

    #expect(taskLine == #"{"data":{"taskID":"t1"},"device":"mac","id":"e3","lamport":3,"type":"TaskDeleted"}"#)
    #expect(
      projectLine == #"{"data":{"projectID":"p1"},"device":"mac","id":"e4","lamport":4,"type":"ProjectDeleted"}"#)
    #expect(
      promotedLine
        == #"{"data":{"projectID":"p1","taskID":"t1"},"device":"mac","id":"e5","lamport":5,"type":"TaskPromotedToProject"}"#
    )
  }

  @Test(
    "each decodes back to the same event",
    arguments: [
      duplicated("t1", as: "t2", on: "2026-10-19"),
      duplicated("t1", as: "t2"),
      taskDeleted("t1"),
      projectDeleted("p1"),
      promoted("t1", to: "p1"),
    ])
  func structureLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}
