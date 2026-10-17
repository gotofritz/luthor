import LuthorDomain
import LuthorTestSupport
import Testing

private let monday = date("2026-10-19")

private func plan(
  _ events: [EventEnvelope],
  view: String = "default",
  on day: CalendarDate = monday,
  today: CalendarDate = monday
) -> DayPlan {
  LibraryState.replay(events).plan(for: ViewID(view), on: day, today: today)
}

@Suite("When a day's capacity is worked out")
struct DayCapacityTests {
  @Test("the weekday default, less the buffer, is what can be planned")
  func theWeekdayDefaultLessTheBufferIsWhatCanBePlanned() {
    let capacity = plan([]).capacity

    #expect(capacity.availableMinutes == 480)
    #expect(capacity.bufferMinutes == 192)
    #expect(capacity.usableMinutes == 288)
    #expect(capacity.plannedMinutes == 0)
    #expect(capacity.remainingMinutes == 288)
    #expect(!capacity.isOverloaded)
  }

  @Test("a weekend day has no capacity unless it is set")
  func aWeekendDayHasNoCapacityUnlessItIsSet() {
    let saturday = date("2026-10-17")

    #expect(plan([], on: saturday).capacity.availableMinutes == 0)
    #expect(plan([dayCapacitySet(120, on: "2026-10-17", lamport: 1)], on: saturday).capacity.availableMinutes == 120)
  }

  @Test("a capacity set for the day beats the weekday default")
  func aCapacitySetForTheDayBeatsTheWeekdayDefault() {
    let capacity = plan([dayCapacitySet(240, on: "2026-10-19", lamport: 1)]).capacity

    #expect(capacity.availableMinutes == 240)
    #expect(capacity.bufferMinutes == 96)
    #expect(capacity.usableMinutes == 144)
  }

  @Test("the buffer percentage and weekday capacity of the view are used")
  func theBufferPercentageAndWeekdayCapacityOfTheViewAreUsed() {
    let capacity = plan([
      settingChanged(.bufferPercentage, to: "25", lamport: 1),
      settingChanged(.capacityMonday, to: "400", view: "default", lamport: 2),
    ]).capacity

    #expect(capacity.availableMinutes == 400)
    #expect(capacity.bufferMinutes == 100)
    #expect(capacity.usableMinutes == 300)
  }

  @Test("a capacity set for one view leaves another view's day alone")
  func aCapacitySetForOneViewLeavesAnotherViewsDayAlone() {
    let events = [viewCreated("work", "Work", lamport: 1), dayCapacitySet(240, on: "2026-10-19", view: "work")]

    #expect(plan(events, view: "work").capacity.availableMinutes == 240)
    #expect(plan(events, view: "default").capacity.availableMinutes == 480)
  }

  @Test("a buffer percentage outside 0 to 100 and a negative capacity are held to the range")
  func outOfRangeNumbersAreHeldToTheRange() {
    #expect(plan([settingChanged(.bufferPercentage, to: "150", lamport: 1)]).capacity.usableMinutes == 0)
    #expect(plan([settingChanged(.bufferPercentage, to: "-10", lamport: 1)]).capacity.bufferMinutes == 0)
    #expect(plan([dayCapacitySet(-30, on: "2026-10-19", lamport: 1)]).capacity.availableMinutes == 0)
  }

  @Test(
    "the plan is overloaded only when planned minutes exceed the usable ones",
    arguments: [(288, false), (289, true), (60, false)])
  func overloadedOnlyWhenPlannedExceedsUsable(minutes: Int, overloaded: Bool) {
    let capacity = plan([
      captured("t1", "big job", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
      estimated("t1", as: minutes, lamport: 3), scheduled("t1", on: "2026-10-19", lamport: 4),
    ]).capacity

    #expect(capacity.plannedMinutes == minutes)
    #expect(capacity.isOverloaded == overloaded)
    #expect(capacity.remainingMinutes == 288 - minutes)
  }

  @Test("an unestimated task counts at the default estimate and is flagged")
  func anUnestimatedTaskCountsAtTheDefaultEstimateAndIsFlagged() {
    let day = plan([
      settingChanged(.defaultEstimateMinutes, to: "10", lamport: 1),
      captured("t1", "write report", lamport: 2), prioritized("t1", as: .critical, lamport: 3),
      captured("t2", "call bank", lamport: 4), estimated("t2", as: 30, lamport: 5),
      scheduled("t1", on: "2026-10-19", lamport: 6), scheduled("t2", on: "2026-10-19", lamport: 7),
    ])

    #expect(day.capacity.plannedMinutes == 40)
    #expect(day.capacity.unestimatedCount == 1)
    #expect(day.entries.map(\.minutes) == [10, 30])
    #expect(day.entries.map(\.isUnestimated) == [true, false])
  }

  @Test("a task scheduled for another day does not count")
  func aTaskScheduledForAnotherDayDoesNotCount() {
    let day = plan([
      captured("t1", "write report", lamport: 1), estimated("t1", as: 60, lamport: 2),
      scheduled("t1", on: "2026-10-20", lamport: 3),
    ])

    #expect(day.capacity.plannedMinutes == 0)
    #expect(day.entries.isEmpty)
  }
}

@Suite("When the plan of a day is ordered")
struct DayPlanOrderTests {
  static let tasks = [
    captured("t1", "tidy desk", lamport: 1), prioritized("t1", as: .optional, lamport: 2),
    captured("t2", "call bank", lamport: 3), prioritized("t2", as: .important, lamport: 4),
    captured("t3", "write report", lamport: 5), prioritized("t3", as: .critical, lamport: 6),
    captured("t4", "plan trip", lamport: 7), estimated("t4", as: 15, lamport: 8),
    scheduled("t1", on: "2026-10-19", lamport: 9), scheduled("t2", on: "2026-10-19", lamport: 10),
    scheduled("t3", on: "2026-10-19", lamport: 11), scheduled("t4", on: "2026-10-19", lamport: 12),
  ]

  @Test("without an order of my own, A comes before B before C, and no priority last")
  func withoutAnOrderOfMyOwnPriorityDecides() {
    #expect(plan(Self.tasks).entries.map(\.task.title) == ["write report", "call bank", "tidy desk", "plan trip"])
  }

  @Test("each place is explained by its priority")
  func eachPlaceIsExplainedByItsPriority() {
    #expect(plan(Self.tasks).entries.map(\.reason) == ["A priority", "B priority", "C priority", "No priority"])
  }

  @Test("equal priorities follow the order of their project, then the order they were captured")
  func equalPrioritiesFollowTheirProjectThenCaptureOrder() {
    let day = plan([
      projectCreated("p1", "Move house", kind: .sequential, lamport: 1),
      captured("t1", "free task", lamport: 2), captured("t2", "pack", lamport: 3),
      captured("t3", "hire van", lamport: 4),
      moved("t3", to: "p1", lamport: 5), moved("t2", to: "p1", lamport: 6),
      prioritized("t1", as: .critical, lamport: 7), prioritized("t2", as: .critical, lamport: 8),
      prioritized("t3", as: .critical, lamport: 9),
      scheduled("t1", on: "2026-10-19", lamport: 10), scheduled("t2", on: "2026-10-19", lamport: 11),
      scheduled("t3", on: "2026-10-19", lamport: 12),
    ])

    // In the project, "hire van" was filed first; the task outside any project follows the project's.
    #expect(day.entries.map(\.task.title) == ["hire van", "pack", "free task"])
    #expect(
      day.entries.map(\.reason) == [
        "A priority, in project Move house", "A priority, in project Move house", "A priority",
      ])
  }

  @Test("an order of my own wins over priority")
  func anOrderOfMyOwnWinsOverPriority() {
    let day = plan(Self.tasks + [planOrdered(["t1", "t4", "t2", "t3"], on: "2026-10-19", lamport: 20)])

    #expect(day.entries.map(\.task.title) == ["tidy desk", "plan trip", "call bank", "write report"])
    #expect(day.entries.map(\.reason) == Array(repeating: "Your order", count: 4))
  }

  @Test("tasks added after my order follow it, in suggested order")
  func tasksAddedAfterMyOrderFollowIt() {
    let day = plan(Self.tasks + [planOrdered(["t1", "t4"], on: "2026-10-19", lamport: 20)])

    #expect(day.entries.map(\.task.title) == ["tidy desk", "plan trip", "write report", "call bank"])
    #expect(day.entries.map(\.reason) == ["Your order", "Your order", "A priority", "B priority"])
  }

  @Test("an order naming tasks that are no longer in the plan skips them, and remembers them")
  func anOrderNamingTasksNoLongerInThePlanSkipsThem() {
    let events = Self.tasks + [planOrdered(["t1", "t3", "t2", "t4"], on: "2026-10-19", lamport: 20)]
    let withoutReport = events + [unscheduled("t3", lamport: 21)]
    let backAgain = withoutReport + [scheduled("t3", on: "2026-10-19", id: "schedule-again", lamport: 22)]

    #expect(plan(withoutReport).entries.map(\.task.title) == ["tidy desk", "call bank", "plan trip"])
    #expect(plan(backAgain).entries.map(\.task.title) == ["tidy desk", "write report", "call bank", "plan trip"])
  }

  @Test("an order of another day does not apply")
  func anOrderOfAnotherDayDoesNotApply() {
    let events = Self.tasks + [planOrdered(["t1", "t4", "t2", "t3"], on: "2026-10-20", lamport: 20)]

    #expect(plan(events).entries.map(\.task.title) == ["write report", "call bank", "tidy desk", "plan trip"])
  }

  @Test("a task named twice in an order takes its first place")
  func aTaskNamedTwiceInAnOrderTakesItsFirstPlace() {
    let day = plan(Self.tasks + [planOrdered(["t4", "t1", "t4"], on: "2026-10-19", lamport: 20)])

    #expect(Array(day.entries.map(\.task.title).prefix(2)) == ["plan trip", "tidy desk"])
    #expect(day.entries.count == 4)
  }
}

@Suite("When the candidates for a day are listed")
struct DayCandidateTests {
  static let tasks = [
    captured("t1", "write report", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
    captured("t2", "call bank", lamport: 3), estimated("t2", as: 30, lamport: 4),
  ]

  @Test("clarified open tasks are candidates, the most urgent first")
  func clarifiedOpenTasksAreCandidates() {
    let day = plan(Self.tasks + [captured("t3", "tidy desk", lamport: 5), prioritized("t3", as: .optional, lamport: 6)])

    #expect(day.candidates.map(\.task.title) == ["write report", "tidy desk", "call bank"])
    #expect(day.candidates.map(\.minutes) == [5, 5, 30])
  }

  @Test("a task still in the inbox is not a candidate until it is clarified")
  func aTaskInTheInboxIsNotACandidate() {
    let day = plan(Self.tasks + [captured("t3", "something", lamport: 5)])

    #expect(day.candidates.map(\.task.title) == ["write report", "call bank"])
  }

  @Test("a someday task is not a candidate")
  func aSomedayTaskIsNotACandidate() {
    let day = plan(Self.tasks + [prioritized("t1", as: .someday, lamport: 5)])

    #expect(day.candidates.map(\.task.title) == ["call bank"])
  }

  @Test("a task already in the day's plan is not a candidate")
  func aTaskAlreadyInThePlanIsNotACandidate() {
    let day = plan(Self.tasks + [scheduled("t1", on: "2026-10-19", lamport: 5)])

    #expect(day.entries.map(\.task.title) == ["write report"])
    #expect(day.candidates.map(\.task.title) == ["call bank"])
  }

  @Test("a task planned for another day is a candidate, to pull forward")
  func aTaskPlannedForAnotherDayIsACandidate() {
    let day = plan(Self.tasks + [scheduled("t1", on: "2026-10-20", lamport: 5)])

    #expect(day.candidates.map(\.task.title) == ["write report", "call bank"])
  }

  @Test("only the next actions of a sequential project are candidates")
  func onlyTheNextActionsOfASequentialProjectAreCandidates() {
    let day = plan([
      projectCreated("p1", "Move house", kind: .sequential, lamport: 1),
      captured("t1", "hire van", lamport: 2), captured("t2", "pack", lamport: 3),
      moved("t1", to: "p1", lamport: 4), moved("t2", to: "p1", lamport: 5),
    ])

    #expect(day.candidates.map(\.task.title) == ["hire van"])
  }

  @Test("a delegated task is not a candidate until its follow-up date")
  func aDelegatedTaskIsNotACandidateUntilItsFollowUpDate() {
    let events = Self.tasks + [delegated("t2", to: "Sam", followUp: "2026-10-21", lamport: 5)]

    #expect(plan(events, today: date("2026-10-19")).candidates.map(\.task.title) == ["write report"])
    #expect(plan(events, today: date("2026-10-20")).candidates.map(\.task.title) == ["write report"])
    #expect(plan(events, today: date("2026-10-21")).candidates.map(\.task.title) == ["write report", "call bank"])
  }

  @Test("a delegated task without a follow-up date stays out until it is reclaimed")
  func aDelegatedTaskWithoutAFollowUpStaysOutUntilReclaimed() {
    let events = Self.tasks + [delegated("t2", to: "Sam", lamport: 5)]

    #expect(plan(events, today: date("2030-01-01")).candidates.map(\.task.title) == ["write report"])
    #expect(plan(events + [reclaimed("t2", lamport: 6)]).candidates.map(\.task.title) == ["write report", "call bank"])
  }

  @Test("candidates of another view never show")
  func candidatesOfAnotherViewNeverShow() {
    let events = [viewCreated("work", "Work", lamport: 1)] + Self.tasks

    #expect(plan(events, view: "work").candidates.isEmpty)
    #expect(plan(events, view: "work").entries.isEmpty)
  }
}

@Suite("When the tasks waited for are listed")
struct WaitingForTests {
  static let log = [
    captured("t1", "get quote", lamport: 1), captured("t2", "book venue", lamport: 2),
    captured("t3", "send invoice", lamport: 3),
    delegated("t2", to: "Kim", since: "2026-10-18", followUp: "2026-10-20", lamport: 4),
    delegated("t1", to: "Sam", since: "2026-10-19", lamport: 5),
  ]

  @Test("each shows who has it and since when, the longest wait first")
  func eachShowsWhoAndSinceWhen() {
    let waiting = LibraryState.replay(Self.log).waitingFor(in: .default, today: date("2026-10-19"))

    #expect(waiting.map(\.task.title) == ["book venue", "get quote"])
    #expect(waiting.map(\.delegation.to) == ["Kim", "Sam"])
    #expect(waiting.map(\.delegation.since) == [date("2026-10-18"), date("2026-10-19")])
  }

  @Test("a follow-up date that has come is flagged")
  func aFollowUpDateThatHasComeIsFlagged() {
    let state = LibraryState.replay(Self.log)

    #expect(state.waitingFor(in: .default, today: date("2026-10-19")).map(\.isFollowUpDue) == [false, false])
    #expect(state.waitingFor(in: .default, today: date("2026-10-20")).map(\.isFollowUpDue) == [true, false])
  }

  @Test("a reclaimed or completed task is no longer waited for")
  func aReclaimedOrCompletedTaskIsNoLongerWaitedFor() {
    let state = LibraryState.replay(Self.log + [reclaimed("t1", lamport: 6), completed("t2", lamport: 7)])

    #expect(state.waitingFor(in: .default, today: date("2026-10-19")).isEmpty)
  }

  @Test("only the view's own delegations show")
  func onlyTheViewsOwnDelegationsShow() {
    let state = LibraryState.replay([viewCreated("work", "Work", lamport: 0)] + Self.log)

    #expect(state.waitingFor(in: ViewID("work"), today: date("2026-10-19")).isEmpty)
  }
}
