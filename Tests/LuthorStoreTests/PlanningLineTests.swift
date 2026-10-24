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

  @Test("a DayHoursSet carries minutes after midnight, and none when cleared")
  func dayHoursSetCarriesMinutesAfterMidnight() throws {
    let set = try EventLine.encode(dayHoursSet(480, 1080, on: "2026-10-19", id: "e5", lamport: 5))
    let cleared = try EventLine.encode(dayHoursSet(nil, nil, on: "2026-10-19", id: "e6", lamport: 6))

    #expect(
      set
        == #"{"data":{"date":"2026-10-19","end":1080,"start":480,"viewID":"default"},"device":"mac","id":"e5","lamport":5,"type":"DayHoursSet"}"#
    )
    #expect(
      cleared
        == #"{"data":{"date":"2026-10-19","viewID":"default"},"device":"mac","id":"e6","lamport":6,"type":"DayHoursSet"}"#
    )
  }

  @Test("a TaskStartSet carries the minute after midnight, and none when cleared")
  func taskStartSetCarriesTheMinuteAfterMidnight() throws {
    let set = try EventLine.encode(startSet("t1", 600, on: "2026-10-19", id: "e7", lamport: 7))
    let cleared = try EventLine.encode(startSet("t1", nil, on: "2026-10-19", id: "e8", lamport: 8))

    #expect(
      set
        == #"{"data":{"date":"2026-10-19","minute":600,"taskID":"t1"},"device":"mac","id":"e7","lamport":7,"type":"TaskStartSet"}"#
    )
    #expect(
      cleared
        == #"{"data":{"date":"2026-10-19","taskID":"t1"},"device":"mac","id":"e8","lamport":8,"type":"TaskStartSet"}"#
    )
  }

  @Test("a DayBlockSet carries its title and minutes after midnight")
  func dayBlockSetCarriesTitleAndMinutes() throws {
    let line = try EventLine.encode(blockSet("b1", "Lunch", 750, 810, on: "2026-10-19", id: "e9", lamport: 9))
    let removed = try EventLine.encode(blockRemoved("b1", id: "e10", lamport: 10))

    #expect(
      line
        == #"{"data":{"blockID":"b1","date":"2026-10-19","end":810,"start":750,"title":"Lunch","viewID":"default"},"device":"mac","id":"e9","lamport":9,"type":"DayBlockSet"}"#
    )
    #expect(removed == #"{"data":{"blockID":"b1"},"device":"mac","id":"e10","lamport":10,"type":"DayBlockRemoved"}"#)
  }

  @Test("a TaskSessionSet carries the task, the start and the minutes")
  func taskSessionSetCarriesTheMinutes() throws {
    let line = try EventLine.encode(sessionSet("s1", "t1", 540, 30, on: "2026-10-19", id: "e11", lamport: 11))
    let removed = try EventLine.encode(sessionRemoved("s1", id: "e12", lamport: 12))

    #expect(
      line
        == #"{"data":{"date":"2026-10-19","minutes":30,"sessionID":"s1","start":540,"taskID":"t1"},"device":"mac","id":"e11","lamport":11,"type":"TaskSessionSet"}"#
    )
    #expect(removed == #"{"data":{"sessionID":"s1"},"device":"mac","id":"e12","lamport":12,"type":"TaskSessionRemoved"}"#)
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
      dayCapacitySet(nil, on: "2026-10-19"), dayHoursSet(480, 1080, on: "2026-10-19"),
      dayHoursSet(nil, nil, on: "2026-10-19"), startSet("t1", 600, on: "2026-10-19"),
      startSet("t1", nil, on: "2026-10-19"), delegated("t1", to: "Sam"),
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
