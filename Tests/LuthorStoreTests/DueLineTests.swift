import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a due date event is written to the log")
struct DueLineTests {
  @Test("a TaskDueSet is one sorted JSON object with the day as text")
  func taskDueSetIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(dueSet("t1", on: "2026-10-23", id: "e1", lamport: 1))

    #expect(
      line
        == #"{"data":{"date":"2026-10-23","isHard":true,"taskID":"t1"},"device":"mac","id":"e1","lamport":1,"type":"TaskDueSet"}"#
    )
  }

  @Test("clearing a due date has no date field")
  func clearingHasNoDateField() throws {
    let line = try EventLine.encode(dueSet("t1", on: nil, id: "e2", lamport: 2))

    #expect(
      line
        == #"{"data":{"isHard":false,"taskID":"t1"},"device":"mac","id":"e2","lamport":2,"type":"TaskDueSet"}"#
    )
  }

  @Test(
    "each decodes back to the same event",
    arguments: [
      dueSet("t1", on: "2026-10-23"), dueSet("t1", on: "2026-10-23", hard: false), dueSet("t1", on: nil),
    ])
  func dueLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}
