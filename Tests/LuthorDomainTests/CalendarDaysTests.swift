import LuthorDomain
import LuthorTestSupport
import Testing

private let monday = date("2026-10-19")

private func days(
  _ events: [EventEnvelope], view: String = "default", from start: String = "2026-10-19", count: Int = 7
) -> [CalendarDay] {
  LibraryState.replay(events).calendar(for: ViewID(view), from: date(start), days: count)
}

private func entries(_ events: [EventEnvelope], view: String = "default", on day: String) -> [CalendarEntry] {
  LibraryState.replay(events).calendarEntries(for: ViewID(view), on: date(day), today: monday)
}

private let tasks = [
  captured("t1", "pay tax", lamport: 1), captured("t2", "write report", lamport: 1),
  captured("t3", "call bank", lamport: 1),
]

@Suite("When the calendar lists days")
struct CalendarDayListTests {
  @Test("it lists that many days in a row from the first")
  func itListsThatManyDaysInARow() {
    let listed = days([], from: "2026-10-29", count: 5)

    #expect(listed.map(\.date) == ["2026-10-29", "2026-10-30", "2026-10-31", "2026-11-01", "2026-11-02"].map(date))
  }

  @Test("no days, or a negative number of them, is an empty list")
  func noDaysIsAnEmptyList() {
    #expect(days([], count: 0).isEmpty)
    #expect(days([], count: -3).isEmpty)
  }

  @Test("a day with nothing planned or due has no marks")
  func aDayWithNothingHasNoMarks() {
    let listed = days(tasks)

    #expect(listed.allSatisfy { !$0.hasTasks })
    #expect(listed.allSatisfy { $0.plannedCount == 0 && $0.dueCount == 0 })
  }

  @Test("a day shows how many tasks are planned for it")
  func aDayShowsHowManyTasksArePlannedForIt() {
    let listed = days(tasks + [scheduled("t1", on: "2026-10-20"), scheduled("t2", on: "2026-10-20")])

    #expect(listed.map(\.plannedCount) == [0, 2, 0, 0, 0, 0, 0])
    #expect(listed.map(\.dueCount) == [0, 0, 0, 0, 0, 0, 0])
    #expect(listed[1].hasTasks)
  }

  @Test("a day shows how many tasks are due on it, hard or target")
  func aDayShowsHowManyTasksAreDueOnIt() {
    let listed = days(tasks + [dueSet("t1", on: "2026-10-22"), dueSet("t2", on: "2026-10-22", hard: false)])

    #expect(listed.map(\.dueCount) == [0, 0, 0, 2, 0, 0, 0])
    #expect(listed.map(\.plannedCount) == [0, 0, 0, 0, 0, 0, 0])
    #expect(listed[3].hasTasks)
  }

  @Test("planned and due are counted apart on the same day")
  func plannedAndDueAreCountedApart() {
    let listed = days(tasks + [scheduled("t1", on: "2026-10-21"), dueSet("t2", on: "2026-10-21")])

    #expect(listed[2].plannedCount == 1)
    #expect(listed[2].dueCount == 1)
  }

  @Test("days outside the list are not counted")
  func daysOutsideTheListAreNotCounted() {
    let listed = days(tasks + [scheduled("t1", on: "2026-10-18"), dueSet("t2", on: "2026-10-26")])

    #expect(listed.allSatisfy { !$0.hasTasks })
  }

  @Test("another view's tasks leave the days alone")
  func anotherViewsTasksLeaveTheDaysAlone() {
    let events =
      tasks + [
        captured("w1", "ship release", view: "work", lamport: 1), scheduled("w1", on: "2026-10-20"),
        dueSet("w1", on: "2026-10-21"),
      ]

    #expect(days(events).allSatisfy { !$0.hasTasks })
    #expect(days(events, view: "work").map(\.hasTasks) == [false, true, true, false, false, false, false])
  }

  @Test("a completed or dropped task leaves its days")
  func aCompletedOrDroppedTaskLeavesItsDays() {
    let events =
      tasks + [
        scheduled("t1", on: "2026-10-20"), dueSet("t1", on: "2026-10-21"), completed("t1", lamport: 5),
        scheduled("t2", on: "2026-10-20"), dueSet("t2", on: "2026-10-21"), dropped("t2", lamport: 6),
      ]

    #expect(days(events).allSatisfy { !$0.hasTasks })
  }

  @Test("a task moved to another day is counted on the new one only")
  func aTaskMovedToAnotherDayIsCountedOnTheNewOneOnly() {
    let events = tasks + [scheduled("t1", on: "2026-10-20"), scheduled("t1", on: "2026-10-22", lamport: 5)]

    #expect(days(events).map(\.plannedCount) == [0, 0, 0, 1, 0, 0, 0])
  }
}

@Suite("When a day is picked on the calendar")
struct CalendarEntriesTests {
  @Test("a day with nothing lists nothing")
  func aDayWithNothingListsNothing() {
    #expect(entries(tasks, on: "2026-10-20").isEmpty)
  }

  @Test("the tasks planned for the day come in plan order")
  func theTasksPlannedForTheDayComeInPlanOrder() {
    let events =
      tasks + [
        prioritized("t1", as: .important), prioritized("t2", as: .critical), scheduled("t1", on: "2026-10-20"),
        scheduled("t2", on: "2026-10-20"),
      ]

    let listed = entries(events, on: "2026-10-20")

    #expect(listed.map(\.task.title) == ["write report", "pay tax"])
    #expect(listed.allSatisfy { $0.isPlanned && $0.due == nil })
  }

  @Test("a task due on the day but planned for none is listed after the planned ones")
  func aTaskDueButNotPlannedIsListedAfterThePlannedOnes() {
    let events =
      tasks + [
        scheduled("t3", on: "2026-10-22"), dueSet("t1", on: "2026-10-22"),
        dueSet("t2", on: "2026-10-22", hard: false),
      ]

    let listed = entries(events, on: "2026-10-22")

    #expect(listed.map(\.task.title) == ["call bank", "pay tax", "write report"])
    #expect(listed.map(\.isPlanned) == [true, false, false])
    let hard = DueDate(date: date("2026-10-22"), isHard: true)
    let target = DueDate(date: date("2026-10-22"), isHard: false)
    #expect(listed.map(\.due) == [nil, hard, target])
  }

  @Test("a task planned and due on the day is listed once, as both")
  func aTaskPlannedAndDueIsListedOnce() {
    let listed = entries(tasks + [scheduled("t1", on: "2026-10-22"), dueSet("t1", on: "2026-10-22")], on: "2026-10-22")

    #expect(listed.count == 1)
    #expect(listed.first?.isPlanned == true)
    #expect(listed.first?.due == DueDate(date: date("2026-10-22"), isHard: true))
  }

  @Test("a task planned for the day that is due on another is not shown as due")
  func aTaskDueOnAnotherDayIsNotShownAsDue() {
    let listed = entries(tasks + [scheduled("t1", on: "2026-10-20"), dueSet("t1", on: "2026-10-25")], on: "2026-10-20")

    #expect(listed.first?.due == nil)
  }

  @Test("another view's tasks are not listed")
  func anotherViewsTasksAreNotListed() {
    let events =
      tasks + [
        captured("w1", "ship release", view: "work", lamport: 1), scheduled("w1", on: "2026-10-20"),
        dueSet("w1", on: "2026-10-20"),
      ]

    #expect(entries(events, on: "2026-10-20").isEmpty)
    #expect(entries(events, view: "work", on: "2026-10-20").map(\.task.title) == ["ship release"])
  }
}
