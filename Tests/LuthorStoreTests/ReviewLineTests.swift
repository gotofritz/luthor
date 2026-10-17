import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a review event is written to the log")
struct ReviewLineTests {
  @Test("a TaskTimeLogged is one sorted JSON object with the day as text")
  func taskTimeLoggedIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(timeLogged("t1", on: "2026-10-19", minutes: 45, id: "e1", lamport: 1))

    #expect(
      line
        == #"{"data":{"date":"2026-10-19","minutes":45,"taskID":"t1"},"device":"mac","id":"e1","lamport":1,"type":"TaskTimeLogged"}"#
    )
  }

  @Test("clearing the time of a day has no minutes field")
  func clearingHasNoMinutesField() throws {
    let line = try EventLine.encode(unplannedTimeLogged(nil, on: "2026-10-19", id: "e2", lamport: 2))

    #expect(
      line
        == #"{"data":{"date":"2026-10-19","viewID":"default"},"device":"mac","id":"e2","lamport":2,"type":"UnplannedTimeLogged"}"#
    )
  }

  @Test("a DayReviewed without a note has no note field")
  func dayReviewedWithoutANoteHasNoNoteField() throws {
    let line = try EventLine.encode(dayReviewed(on: "2026-10-19", id: "e3", lamport: 3))

    #expect(
      line
        == #"{"data":{"date":"2026-10-19","viewID":"default"},"device":"mac","id":"e3","lamport":3,"type":"DayReviewed"}"#
    )
  }

  @Test(
    "each decodes back to the same event",
    arguments: [
      timeLogged("t1", on: "2026-10-19", minutes: 45), timeLogged("t1", on: "2026-10-19", minutes: nil),
      unplannedTimeLogged(25, on: "2026-10-19"), unplannedTimeLogged(nil, on: "2026-10-19", view: "work"),
      dayReviewed(on: "2026-10-19", note: "Too many calls"), dayReviewed(on: "2026-10-19"),
    ])
  func reviewLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}
