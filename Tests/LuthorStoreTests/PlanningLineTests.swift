import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a planning event is written to the log")
struct PlanningLineTests {
  @Test("a TaskScheduled is one sorted JSON object with the day as text")
  func taskScheduledIsOneSortedJSONObject() throws {
    let line = try EventLine.encode(scheduled("t1", on: "2026-10-19", id: "e1", lamport: 1))

    #expect(
      line
        == #"{"data":{"date":"2026-10-19","taskID":"t1"},"device":"mac","id":"e1","lamport":1,"type":"TaskScheduled"}"#
    )
  }

  @Test("a DayPlanOrdered lists the tasks in order")
  func dayPlanOrderedListsTheTasksInOrder() throws {
    let line = try EventLine.encode(planOrdered(["t2", "t1"], on: "2026-10-19", view: "work", id: "e2", lamport: 2))

    #expect(
      line
        == #"{"data":{"date":"2026-10-19","taskIDs":["t2","t1"],"viewID":"work"},"device":"mac","id":"e2","lamport":2,"type":"DayPlanOrdered"}"#
    )
  }

  @Test("clearing a day's capacity has no minutes field")
  func clearingHasNoMinutesField() throws {
    let line = try EventLine.encode(dayCapacitySet(nil, on: "2026-10-19", id: "e3", lamport: 3))

    #expect(
      line
        == #"{"data":{"date":"2026-10-19","viewID":"default"},"device":"mac","id":"e3","lamport":3,"type":"DayCapacitySet"}"#
    )
  }

  @Test("a TaskDelegated without a follow-up date has no follow-up field")
  func taskDelegatedWithoutAFollowUpHasNoFollowUpField() throws {
    let line = try EventLine.encode(delegated("t1", to: "Sam", since: "2026-10-19", id: "e4", lamport: 4))

    #expect(
      line
        == #"{"data":{"since":"2026-10-19","taskID":"t1","to":"Sam"},"device":"mac","id":"e4","lamport":4,"type":"TaskDelegated"}"#
    )
  }

  @Test(
    "each decodes back to the same event",
    arguments: [
      scheduled("t1", on: "2026-10-19"), unscheduled("t1"), planOrdered(["t2", "t1"], on: "2026-10-19"),
      planOrdered([], on: "2026-10-19", view: "work"), dayCapacitySet(240, on: "2026-10-19"),
      dayCapacitySet(nil, on: "2026-10-19"), delegated("t1", to: "Sam"),
      delegated("t1", to: "Sam", followUp: "2026-10-21"), reclaimed("t1"), dropped("t1"),
    ])
  func planningLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }

  @Test("a line with a date that is not a day is unreadable")
  func aLineWithADateThatIsNotADayIsUnreadable() {
    let line =
      #"{"data":{"date":"2026-02-30","taskID":"t1"},"device":"mac","id":"e1","lamport":1,"type":"TaskScheduled"}"#

    #expect(throws: EventLogError.unreadableLine(0)) { try EventLine.decode(line) }
  }
}
