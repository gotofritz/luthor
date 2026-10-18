import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a project review event is written to the log")
struct ProjectReviewLineTests {
  @Test("a review interval is its number of days, and off is 0")
  func aReviewIntervalIsItsNumberOfDays() throws {
    let weekly = try EventLine.encode(reviewDefaultSet(.every(days: 7), id: "e1", lamport: 1))
    let off = try EventLine.encode(reviewDefaultSet(.off, id: "e2", lamport: 2))

    #expect(weekly == #"{"data":{"interval":7},"device":"mac","id":"e1","lamport":1,"type":"ReviewDefaultSet"}"#)
    #expect(off == #"{"data":{"interval":0},"device":"mac","id":"e2","lamport":2,"type":"ReviewDefaultSet"}"#)
  }

  @Test("a project's own interval names the project, and none is left out")
  func aProjectsOwnIntervalNamesTheProject() throws {
    let own = try EventLine.encode(reviewIntervalSet("p1", to: .every(days: 3), id: "e1", lamport: 1))
    let cleared = try EventLine.encode(reviewIntervalSet("p1", to: nil, id: "e2", lamport: 2))

    #expect(
      own
        == #"{"data":{"interval":3,"projectID":"p1"},"device":"mac","id":"e1","lamport":1,"type":"ProjectReviewIntervalSet"}"#
    )
    #expect(
      cleared
        == #"{"data":{"projectID":"p1"},"device":"mac","id":"e2","lamport":2,"type":"ProjectReviewIntervalSet"}"#)
  }

  @Test("a review names the project and the day")
  func aReviewNamesTheProjectAndTheDay() throws {
    let line = try EventLine.encode(projectReviewed("p1", on: "2026-10-19", id: "e1", lamport: 1))

    #expect(
      line
        == #"{"data":{"date":"2026-10-19","projectID":"p1"},"device":"mac","id":"e1","lamport":1,"type":"ProjectReviewed"}"#
    )
  }

  @Test("a status change names the project")
  func aStatusChangeNamesTheProject() throws {
    let hold = try EventLine.encode(projectPutOnHold("p1", id: "e1", lamport: 1))
    let resume = try EventLine.encode(projectResumed("p1", id: "e2", lamport: 2))
    let drop = try EventLine.encode(projectDropped("p1", id: "e3", lamport: 3))

    #expect(hold == #"{"data":{"projectID":"p1"},"device":"mac","id":"e1","lamport":1,"type":"ProjectPutOnHold"}"#)
    #expect(resume == #"{"data":{"projectID":"p1"},"device":"mac","id":"e2","lamport":2,"type":"ProjectResumed"}"#)
    #expect(drop == #"{"data":{"projectID":"p1"},"device":"mac","id":"e3","lamport":3,"type":"ProjectDropped"}"#)
  }

  @Test(
    "each decodes back to the same event",
    arguments: [
      reviewDefaultSet(.every(days: 7)), reviewDefaultSet(.off), reviewIntervalSet("p1", to: .every(days: 3)),
      reviewIntervalSet("p1", to: .off), reviewIntervalSet("p1", to: nil), projectReviewed("p1", on: "2026-10-19"),
      projectPutOnHold("p1"), projectResumed("p1"), projectDropped("p1"),
    ])
  func projectReviewLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }

  @Test("an interval of no days, or fewer, reads back as off")
  func noDaysReadsBackAsOff() throws {
    let line = #"{"data":{"interval":-2},"device":"mac","id":"e1","lamport":1,"type":"ReviewDefaultSet"}"#

    #expect(try EventLine.decode(line) == reviewDefaultSet(.off, id: "e1", lamport: 1))
  }
}
