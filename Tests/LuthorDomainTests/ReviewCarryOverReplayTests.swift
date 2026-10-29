import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When tasks are left over from earlier days")
struct CarryOverReplayTests {
  @Test("open tasks planned for a day before today are left over, oldest day first")
  func openTasksPlannedBeforeTodayAreLeftOver() {
    let state = LibraryState.replay([
      captured("t1", "write report", lamport: 1), captured("t2", "call bank", lamport: 2),
      scheduled("t1", on: "2026-10-19", lamport: 3), scheduled("t2", on: "2026-10-18", lamport: 4),
    ])

    let leftOver = state.carryOver(in: .default, today: date("2026-10-20"))

    #expect(leftOver.map(\.entry.task.title) == ["call bank", "write report"])
    #expect(leftOver.map(\.plannedFor) == [date("2026-10-18"), date("2026-10-19")])
  }

  @Test("within a day they follow the suggested order")
  func withinADayTheyFollowTheSuggestedOrder() {
    let state = LibraryState.replay([
      captured("t1", "tidy desk", lamport: 1), prioritized("t1", as: .optional, lamport: 2),
      captured("t2", "write report", lamport: 3), prioritized("t2", as: .critical, lamport: 4),
      scheduled("t1", on: "2026-10-19", lamport: 5), scheduled("t2", on: "2026-10-19", lamport: 6),
    ])

    let leftOver = state.carryOver(in: .default, today: date("2026-10-20"))

    #expect(leftOver.map(\.entry.task.title) == ["write report", "tidy desk"])
  }

  @Test("each says where it was left from, and counts at its estimate")
  func eachSaysWhereItWasLeftFrom() {
    let state = LibraryState.replay([
      captured("t1", "write report", lamport: 1), estimated("t1", as: 60, lamport: 2),
      prioritized("t1", as: .critical, lamport: 3),
      captured("t2", "tidy desk", lamport: 4), prioritized("t2", as: .optional, lamport: 5),
      scheduled("t1", on: "2026-10-19", lamport: 6), scheduled("t2", on: "2026-10-19", lamport: 7),
    ])

    let leftOver = state.carryOver(in: .default, today: date("2026-10-20"))

    #expect(leftOver.map(\.entry.reason) == ["Left over from 2026-10-19", "Left over from 2026-10-19"])
    #expect(leftOver.map(\.entry.minutes) == [60, 5])
    #expect(leftOver.map(\.entry.isUnestimated) == [false, true])
  }

  @Test("tasks planned for today or later are not left over")
  func tasksPlannedForTodayOrLaterAreNotLeftOver() {
    let state = LibraryState.replay([
      captured("t1", "write report", lamport: 1), captured("t2", "call bank", lamport: 2),
      scheduled("t1", on: "2026-10-20", lamport: 3), scheduled("t2", on: "2026-10-21", lamport: 4),
    ])

    #expect(state.carryOver(in: .default, today: date("2026-10-20")).isEmpty)
  }

  @Test("completed, dropped and delegated tasks are not left over")
  func completedDroppedAndDelegatedTasksAreNotLeftOver() {
    let state = LibraryState.replay([
      captured("t1", "write report", lamport: 1), captured("t2", "call bank", lamport: 2),
      captured("t3", "ask Sam", lamport: 3),
      scheduled("t1", on: "2026-10-19", lamport: 4), scheduled("t2", on: "2026-10-19", lamport: 5),
      scheduled("t3", on: "2026-10-19", lamport: 6),
      completed("t1", lamport: 7), dropped("t2", lamport: 8), delegated("t3", to: "Sam", lamport: 9),
    ])

    #expect(state.carryOver(in: .default, today: date("2026-10-20")).isEmpty)
  }

  @Test("the leftovers of one view are not those of another")
  func theLeftoversOfOneViewAreNotThoseOfAnother() {
    let state = LibraryState.replay([
      viewCreated("work", "Work", lamport: 1), captured("t1", "write report", view: "work", lamport: 2),
      scheduled("t1", on: "2026-10-19", lamport: 3),
    ])

    #expect(state.carryOver(in: .default, today: date("2026-10-20")).isEmpty)
    #expect(state.carryOver(in: ViewID("work"), today: date("2026-10-20")).count == 1)
  }

  @Test("a left over task is not also a candidate")
  func aLeftOverTaskIsNotAlsoACandidate() {
    let state = LibraryState.replay([
      captured("t1", "write report", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
      captured("t2", "call bank", lamport: 3), prioritized("t2", as: .important, lamport: 4),
      scheduled("t1", on: "2026-10-19", lamport: 5), scheduled("t2", on: "2026-10-21", lamport: 6),
    ])

    let plan = state.plan(for: .default, on: date("2026-10-20"), today: date("2026-10-20"))

    #expect(plan.candidates.map(\.task.title) == ["call bank"])
  }

  @Test("deciding a task takes it out of the leftovers")
  func decidingATaskTakesItOutOfTheLeftovers() {
    let base = [
      captured("t1", "write report", lamport: 1), scheduled("t1", on: "2026-10-19", lamport: 2),
    ]
    let today = date("2026-10-20")

    let rescheduled = LibraryState.replay(base + [scheduled("t1", on: "2026-10-20", lamport: 3)])
    let unplanned = LibraryState.replay(base + [unscheduled("t1", lamport: 3)])
    let handedOver = LibraryState.replay(base + [delegated("t1", to: "Sam", lamport: 3)])
    let someday = LibraryState.replay(
      base + [prioritized("t1", as: .someday, lamport: 3), unscheduled("t1", lamport: 4)])

    for state in [rescheduled, unplanned, handedOver, someday] {
      #expect(state.carryOver(in: .default, today: today).isEmpty)
    }
  }
}

@Suite("When estimates are looked back on")
struct EstimateHistoryReplayTests {
  @Test("a task shows its estimate against the minutes logged over all days")
  func aTaskShowsItsEstimateAgainstTheMinutesLogged() {
    let state = LibraryState.replay(
      plannedMonday + [
        timeLogged("t1", on: "2026-10-19", minutes: 50, lamport: 13),
        timeLogged("t1", on: "2026-10-20", minutes: 40, lamport: 14),
      ])

    let history = state.estimateHistory(ofTask: TaskID("t1"))

    #expect(history == EstimateHistory(estimatedMinutes: 60, loggedMinutes: 90, taskCount: 1))
    #expect(history?.differenceMinutes == 30)
  }

  @Test("a task with no estimate, or with no time logged, has no history")
  func aTaskWithNoEstimateOrNoTimeHasNoHistory() {
    let state = LibraryState.replay(plannedMonday + [timeLogged("t3", on: "2026-10-19", minutes: 20, lamport: 13)])

    #expect(state.estimateHistory(ofTask: TaskID("t3")) == nil)
    #expect(state.estimateHistory(ofTask: TaskID("t2")) == nil)
    #expect(state.estimateHistory(ofTask: TaskID("unknown")) == nil)
  }

  @Test("a day's time that is changed or cleared is counted as it last stood")
  func aDaysTimeChangedOrClearedIsCountedAsItLastStood() {
    let changed = LibraryState.replay(
      plannedMonday + [
        timeLogged("t1", on: "2026-10-19", minutes: 50, lamport: 13),
        timeLogged("t1", on: "2026-10-20", minutes: 40, lamport: 14),
        timeLogged("t1", on: "2026-10-19", minutes: 10, id: "again", lamport: 15),
      ])
    let cleared = LibraryState.replay(
      plannedMonday + [
        timeLogged("t1", on: "2026-10-19", minutes: 50, lamport: 13),
        timeLogged("t1", on: "2026-10-19", minutes: nil, lamport: 14),
      ])

    #expect(changed.estimateHistory(ofTask: TaskID("t1"))?.loggedMinutes == 50)
    #expect(cleared.estimateHistory(ofTask: TaskID("t1")) == nil)
  }

  @Test("a task deleted for good leaves no logged time behind")
  func aDeletedTaskLeavesNoLoggedTime() {
    let state = LibraryState.replay(
      plannedMonday + [timeLogged("t1", on: "2026-10-19", minutes: 50, lamport: 13), taskDeleted("t1", lamport: 14)])

    #expect(state.estimateHistory(ofTask: TaskID("t1")) == nil)
  }

  @Test("the history is never applied: the estimate stays what the user set")
  func theHistoryIsNeverApplied() {
    let state = LibraryState.replay(plannedMonday + [timeLogged("t2", on: "2026-10-19", minutes: 80, lamport: 13)])

    #expect(state.view(.default).openTasks.first { $0.id == TaskID("t2") }?.estimate == 30)
  }

  @Test("a project adds up the tasks in it, sub-projects too, that have both an estimate and logged time")
  func aProjectAddsUpItsTasks() {
    let state = LibraryState.replay([
      projectCreated("p1", "Move house", lamport: 1), projectCreated("p2", "Kitchen", under: "p1", lamport: 2),
      captured("t1", "pack books", lamport: 3), moved("t1", to: "p1", lamport: 4), estimated("t1", as: 30, lamport: 5),
      captured("t2", "replace tap", lamport: 6), moved("t2", to: "p2", lamport: 7), estimated("t2", as: 60, lamport: 8),
      captured("t3", "call movers", lamport: 9), moved("t3", to: "p1", lamport: 10),
      timeLogged("t1", on: "2026-10-19", minutes: 45, lamport: 11),
      timeLogged("t2", on: "2026-10-19", minutes: 90, lamport: 12),
      timeLogged("t3", on: "2026-10-19", minutes: 15, lamport: 13), completed("t1", lamport: 14),
    ])

    let history = state.estimateHistory(ofProject: TaskID("p1"))

    #expect(history == EstimateHistory(estimatedMinutes: 90, loggedMinutes: 135, taskCount: 2))
  }

  @Test("a project with nothing logged has no history")
  func aProjectWithNothingLoggedHasNoHistory() {
    let state = LibraryState.replay([
      projectCreated("p1", "Move house", lamport: 1), captured("t1", "pack books", lamport: 2),
      moved("t1", to: "p1", lamport: 3), estimated("t1", as: 30, lamport: 4),
    ])

    #expect(state.estimateHistory(ofProject: TaskID("p1")) == nil)
  }
}
