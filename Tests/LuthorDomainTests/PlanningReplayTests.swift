import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When a task is scheduled")
struct ScheduleReplayTests {
  static let base = [captured("t1", "write report", lamport: 1)]

  @Test("it is scheduled for that day")
  func itIsScheduledForThatDay() {
    let state = LibraryState.replay(Self.base + [scheduled("t1", on: "2026-10-19", lamport: 2)])

    #expect(state.scheduledDate(of: TaskID("t1")) == date("2026-10-19"))
  }

  @Test("scheduling it again moves it, and it stays one task")
  func schedulingItAgainMovesIt() {
    let state = LibraryState.replay(
      Self.base + [scheduled("t1", on: "2026-10-19", lamport: 2), scheduled("t1", on: "2026-10-21", lamport: 3)])

    #expect(state.scheduledDate(of: TaskID("t1")) == date("2026-10-21"))
    #expect(state.view(.default).openTasks == [item("t1", "write report")])
  }

  @Test("unscheduling it clears the day")
  func unschedulingItClearsTheDay() {
    let state = LibraryState.replay(
      Self.base + [scheduled("t1", on: "2026-10-19", lamport: 2), unscheduled("t1", lamport: 3)])

    #expect(state.scheduledDate(of: TaskID("t1")) == nil)
  }

  @Test("a task that is not open is ignored")
  func aTaskThatIsNotOpenIsIgnored() {
    let state = LibraryState.replay([scheduled("t9", on: "2026-10-19", lamport: 1)])

    #expect(state.scheduledDate(of: TaskID("t9")) == nil)
  }

  @Test("completing the task forgets the day")
  func completingTheTaskForgetsTheDay() {
    let state = LibraryState.replay(
      Self.base + [scheduled("t1", on: "2026-10-19", lamport: 2), completed("t1", lamport: 3)])

    #expect(state.scheduledDate(of: TaskID("t1")) == nil)
  }

  @Test("dropping the task takes it out of every list and forgets the day")
  func droppingTheTaskTakesItOutOfEveryList() {
    let state = LibraryState.replay(
      Self.base + [scheduled("t1", on: "2026-10-19", lamport: 2), dropped("t1", lamport: 3)])

    #expect(state.view(.default).openTasks.isEmpty)
    #expect(state.scheduledDate(of: TaskID("t1")) == nil)
  }

  @Test("dropping a task filed in a project takes it out of the project too")
  func droppingAFiledTaskTakesItOutOfTheProject() {
    let state = LibraryState.replay([
      projectCreated("p1", "Move house", lamport: 1), captured("t1", "pack", lamport: 2),
      moved("t1", to: "p1", lamport: 3), dropped("t1", lamport: 4),
    ])

    #expect(state.view(.default).projects == [project("p1", "Move house")])
  }

  @Test("taking the task across to another view forgets the day")
  func takingTheTaskAcrossForgetsTheDay() {
    let state = LibraryState.replay(
      [viewCreated("work", "Work", lamport: 1)] + Self.base
        + [scheduled("t1", on: "2026-10-19", lamport: 2), movedToView("t1", toView: "work", lamport: 3)])

    #expect(state.scheduledDate(of: TaskID("t1")) == nil)
  }
}

@Suite("When a task is delegated")
struct DelegationReplayTests {
  static let base = [captured("t1", "get quote", lamport: 1), scheduled("t1", on: "2026-10-19", lamport: 2)]

  @Test("it is waiting on the person, since the day, with its follow-up date")
  func itIsWaitingOnThePerson() {
    let state = LibraryState.replay(Self.base + [delegated("t1", to: "Sam", followUp: "2026-10-21", lamport: 3)])

    #expect(
      state.delegation(of: TaskID("t1"))
        == Delegation(to: "Sam", since: date("2026-10-19"), followUpDate: date("2026-10-21")))
  }

  @Test("it leaves the day it was scheduled for")
  func itLeavesTheDay() {
    let state = LibraryState.replay(Self.base + [delegated("t1", to: "Sam", lamport: 3)])

    #expect(state.scheduledDate(of: TaskID("t1")) == nil)
  }

  @Test("it stays open: delegating completes nothing")
  func itStaysOpen() {
    let state = LibraryState.replay(Self.base + [delegated("t1", to: "Sam", lamport: 3)])

    #expect(state.view(.default).openTasks == [item("t1", "get quote")])
  }

  @Test("it cannot be scheduled while it is delegated")
  func itCannotBeScheduledWhileDelegated() {
    let state = LibraryState.replay(
      Self.base + [delegated("t1", to: "Sam", lamport: 3), scheduled("t1", on: "2026-10-20", lamport: 4)])

    #expect(state.scheduledDate(of: TaskID("t1")) == nil)
  }

  @Test("delegating it to someone else replaces the first person")
  func delegatingToSomeoneElseReplacesTheFirst() {
    let state = LibraryState.replay(
      Self.base + [delegated("t1", to: "Sam", lamport: 3), delegated("t1", to: "Kim", lamport: 4)])

    #expect(state.delegation(of: TaskID("t1"))?.person == "Kim")
  }

  @Test("reclaiming it ends the delegation")
  func reclaimingItEndsTheDelegation() {
    let state = LibraryState.replay(
      Self.base + [delegated("t1", to: "Sam", lamport: 3), reclaimed("t1", lamport: 4)])

    #expect(state.delegation(of: TaskID("t1")) == nil)
    #expect(state.view(.default).openTasks == [item("t1", "get quote")])
  }

  @Test("a task that is not open is ignored")
  func aTaskThatIsNotOpenIsIgnored() {
    let state = LibraryState.replay([delegated("t9", to: "Sam", lamport: 1)])

    #expect(state.delegation(of: TaskID("t9")) == nil)
  }

  @Test("completing the task ends the delegation")
  func completingTheTaskEndsTheDelegation() {
    let state = LibraryState.replay(
      Self.base + [delegated("t1", to: "Sam", lamport: 3), completed("t1", lamport: 4)])

    #expect(state.delegation(of: TaskID("t1")) == nil)
  }
}

@Suite("When a day's plan is ordered and its capacity set")
struct DayPlanReplayTests {
  @Test("the last order set for the view and day is kept")
  func theLastOrderIsKept() {
    let state = LibraryState.replay([
      planOrdered(["t1", "t2"], on: "2026-10-19", lamport: 1),
      planOrdered(["t2", "t1"], on: "2026-10-19", lamport: 2),
      planOrdered(["t1"], on: "2026-10-20", lamport: 3),
    ])

    #expect(state.manualOrder(in: .default, on: date("2026-10-19")) == [TaskID("t2"), TaskID("t1")])
    #expect(state.manualOrder(in: .default, on: date("2026-10-20")) == [TaskID("t1")])
    #expect(state.manualOrder(in: .default, on: date("2026-10-21")) == nil)
  }

  @Test("an order belongs to one view")
  func anOrderBelongsToOneView() {
    let state = LibraryState.replay([
      viewCreated("work", "Work", lamport: 1), planOrdered(["t1"], on: "2026-10-19", view: "work", lamport: 2),
    ])

    #expect(state.manualOrder(in: ViewID("work"), on: date("2026-10-19")) == [TaskID("t1")])
    #expect(state.manualOrder(in: .default, on: date("2026-10-19")) == nil)
  }

  @Test("a capacity set for a day overrides that day only")
  func aCapacitySetForADayOverridesThatDayOnly() {
    let state = LibraryState.replay([dayCapacitySet(240, on: "2026-10-19", lamport: 1)])

    #expect(state.capacityOverride(in: .default, on: date("2026-10-19")) == 240)
    #expect(state.capacityOverride(in: .default, on: date("2026-10-20")) == nil)
  }

  @Test("clearing it falls back to the weekday")
  func clearingItFallsBackToTheWeekday() {
    let state = LibraryState.replay([
      dayCapacitySet(240, on: "2026-10-19", lamport: 1), dayCapacitySet(nil, on: "2026-10-19", lamport: 2),
    ])

    #expect(state.capacityOverride(in: .default, on: date("2026-10-19")) == nil)
  }
}

@Suite("When planning events arrive in any order")
struct PlanningReplayOrderTests {
  static let log = [
    captured("t1", "write report", lamport: 1),
    captured("t2", "call bank", lamport: 2),
    scheduled("t1", on: "2026-10-19", lamport: 3),
    scheduled("t2", on: "2026-10-19", lamport: 4),
    planOrdered(["t2", "t1"], on: "2026-10-19", lamport: 5),
    delegated("t2", to: "Sam", lamport: 6),
  ]

  static let arrivalOrders: [[Int]] = [
    [0, 1, 2, 3, 4, 5],
    [5, 4, 3, 2, 1, 0],
    [3, 5, 0, 4, 2, 1],
    [1, 0, 4, 5, 3, 2],
  ]

  @Test(arguments: arrivalOrders)
  func anyArrivalOrderReplaysToTheSameState(order: [Int]) {
    let state = LibraryState.replay(order.map { Self.log[$0] })

    #expect(state == LibraryState.replay(Self.log))
    #expect(state.scheduledDate(of: TaskID("t1")) == date("2026-10-19"))
    #expect(state.delegation(of: TaskID("t2"))?.person == "Sam")
  }

  @Test func duplicateEventsAreAppliedOnce() {
    let state = LibraryState.replay(Self.log + Self.log)

    #expect(state == LibraryState.replay(Self.log))
  }
}
