import LuthorDomain
import LuthorTestSupport
import Testing

private let monday = date("2026-10-19")

/// "write report" (60m) was planned for Monday and completed, "call bank" (30m) and "tidy desk" (no
/// estimate) were planned for Monday and are open, and "read mail" was never planned.
private let plannedMonday = [
  captured("t1", "write report", lamport: 1), estimated("t1", as: 60, lamport: 2),
  captured("t2", "call bank", lamport: 3), estimated("t2", as: 30, lamport: 4),
  captured("t3", "tidy desk", lamport: 5), prioritized("t3", as: .optional, lamport: 6),
  captured("t4", "read mail", lamport: 7), estimated("t4", as: 10, lamport: 8),
  scheduled("t1", on: "2026-10-19", lamport: 9), scheduled("t2", on: "2026-10-19", lamport: 10),
  scheduled("t3", on: "2026-10-19", lamport: 11), completed("t1", lamport: 12),
]

@Suite("When time is logged")
struct TimeLoggedReplayTests {
  @Test("a task has the minutes logged for that day")
  func aTaskHasTheMinutesLoggedForThatDay() {
    let state = LibraryState.replay(plannedMonday + [timeLogged("t1", on: "2026-10-19", minutes: 90, lamport: 13)])

    let review = state.dayReview(for: .default, on: monday, today: monday)

    #expect(review.done.map(\.loggedMinutes) == [90])
    #expect(review.notDone.map(\.loggedMinutes) == [nil, nil])
  }

  @Test("logging again for the same day replaces the minutes, and nothing is added up")
  func loggingAgainReplacesTheMinutes() {
    let state = LibraryState.replay(
      plannedMonday + [
        timeLogged("t1", on: "2026-10-19", minutes: 90, lamport: 13),
        timeLogged("t1", on: "2026-10-19", minutes: 70, lamport: 14),
      ])

    #expect(state.dayReview(for: .default, on: monday, today: monday).done.map(\.loggedMinutes) == [70])
  }

  @Test("clearing, or logging nothing, removes the minutes")
  func clearingRemovesTheMinutes() {
    let cleared = LibraryState.replay(
      plannedMonday + [
        timeLogged("t1", on: "2026-10-19", minutes: 90, lamport: 13),
        timeLogged("t1", on: "2026-10-19", minutes: nil, lamport: 14),
      ])
    let zero = LibraryState.replay(plannedMonday + [timeLogged("t1", on: "2026-10-19", minutes: 0, lamport: 13)])

    #expect(cleared.dayReview(for: .default, on: monday, today: monday).done.map(\.loggedMinutes) == [nil])
    #expect(zero.dayReview(for: .default, on: monday, today: monday).done.map(\.loggedMinutes) == [nil])
  }

  @Test("each day keeps its own minutes")
  func eachDayKeepsItsOwnMinutes() {
    let state = LibraryState.replay(
      plannedMonday + [
        timeLogged("t2", on: "2026-10-19", minutes: 20, lamport: 13),
        timeLogged("t2", on: "2026-10-20", minutes: 45, lamport: 14),
      ])

    let review = state.dayReview(for: .default, on: monday, today: monday)

    #expect(review.notDone.map(\.loggedMinutes) == [20, nil])
    #expect(state.estimateHistory(ofTask: TaskID("t2"))?.loggedMinutes == 65)
  }

  @Test("unplanned minutes belong to one view and one day")
  func unplannedMinutesBelongToOneViewAndOneDay() {
    let state = LibraryState.replay(
      plannedMonday + [
        viewCreated("work", "Work", lamport: 13),
        unplannedTimeLogged(25, on: "2026-10-19", lamport: 14),
        unplannedTimeLogged(40, on: "2026-10-19", view: "work", lamport: 15),
        unplannedTimeLogged(10, on: "2026-10-20", lamport: 16),
      ])

    #expect(state.dayReview(for: .default, on: monday, today: monday).unplannedMinutes == 25)
    #expect(state.dayReview(for: ViewID("work"), on: monday, today: monday).unplannedMinutes == 40)
    #expect(state.dayReview(for: .default, on: date("2026-10-20"), today: monday).unplannedMinutes == 10)
  }

  @Test("clearing the unplanned minutes of a day leaves none")
  func clearingTheUnplannedMinutesLeavesNone() {
    let state = LibraryState.replay(
      plannedMonday + [
        unplannedTimeLogged(25, on: "2026-10-19", lamport: 13), unplannedTimeLogged(nil, on: "2026-10-19", lamport: 14),
      ])

    #expect(state.dayReview(for: .default, on: monday, today: monday).unplannedMinutes == 0)
  }
}

@Suite("When a day is reviewed")
struct DayReviewedReplayTests {
  @Test("it is reviewed, with its note")
  func itIsReviewedWithItsNote() {
    let state = LibraryState.replay(
      plannedMonday + [dayReviewed(on: "2026-10-19", note: "Too many calls", lamport: 13)])

    let review = state.dayReview(for: .default, on: monday, today: monday)

    #expect(review.isReviewed)
    #expect(review.note == "Too many calls")
  }

  @Test("a day nobody reviewed is not reviewed and has no note")
  func aDayNobodyReviewedIsNotReviewed() {
    let review = LibraryState.replay(plannedMonday).dayReview(for: .default, on: monday, today: monday)

    #expect(!review.isReviewed)
    #expect(review.note == nil)
  }

  @Test("reviewing a day again replaces its note")
  func reviewingADayAgainReplacesItsNote() {
    let state = LibraryState.replay(
      plannedMonday + [
        dayReviewed(on: "2026-10-19", note: "First thoughts", lamport: 13),
        dayReviewed(on: "2026-10-19", note: nil, lamport: 14),
      ])

    let review = state.dayReview(for: .default, on: monday, today: monday)

    #expect(review.isReviewed)
    #expect(review.note == nil)
  }

  @Test("the review is of one view and one day")
  func theReviewIsOfOneViewAndOneDay() {
    let state = LibraryState.replay(
      plannedMonday + [
        viewCreated("work", "Work", lamport: 13), dayReviewed(on: "2026-10-19", view: "work", lamport: 14),
      ])

    #expect(!state.dayReview(for: .default, on: monday, today: monday).isReviewed)
    #expect(state.dayReview(for: ViewID("work"), on: monday, today: monday).isReviewed)
    #expect(!state.dayReview(for: ViewID("work"), on: date("2026-10-20"), today: monday).isReviewed)
  }
}

@Suite("When the day is looked back on")
struct DayReviewContentReplayTests {
  @Test("the tasks planned for the day and completed are done, the ones still open are not")
  func theTasksPlannedAndCompletedAreDone() {
    let review = LibraryState.replay(plannedMonday).dayReview(for: .default, on: monday, today: monday)

    #expect(review.done.map(\.task.title) == ["write report"])
    #expect(review.notDone.map(\.task.title) == ["call bank", "tidy desk"])
  }

  @Test("a task that was never planned for the day is in neither list")
  func aTaskThatWasNeverPlannedIsInNeitherList() {
    let review = LibraryState.replay(plannedMonday + [completed("t4", lamport: 13)])
      .dayReview(for: .default, on: monday, today: monday)

    #expect(!review.done.map(\.task.title).contains("read mail"))
    #expect(!review.notDone.map(\.task.title).contains("read mail"))
  }

  @Test("minutes are the estimate, or the default estimate for a task without one")
  func minutesAreTheEstimateOrTheDefault() {
    let review = LibraryState.replay(plannedMonday).dayReview(for: .default, on: monday, today: monday)

    #expect(review.done.map(\.minutes) == [60])
    #expect(review.notDone.map(\.minutes) == [30, 5])
    #expect(review.notDone.map(\.isUnestimated) == [false, true])
    #expect(review.estimatedMinutes == 95)
  }

  @Test("logged minutes add up over the tasks of the day, and the unplanned ones stay apart")
  func loggedMinutesAddUp() {
    let review = LibraryState.replay(
      plannedMonday + [
        timeLogged("t1", on: "2026-10-19", minutes: 90, lamport: 13),
        timeLogged("t2", on: "2026-10-19", minutes: 20, lamport: 14),
        unplannedTimeLogged(25, on: "2026-10-19", lamport: 15),
      ]
    ).dayReview(for: .default, on: monday, today: monday)

    #expect(review.loggedMinutes == 110)
    #expect(review.unplannedMinutes == 25)
  }

  @Test("the tasks not done keep the order of the plan")
  func theTasksNotDoneKeepTheOrderOfThePlan() {
    let review = LibraryState.replay(plannedMonday + [planOrdered(["t3", "t2"], on: "2026-10-19", lamport: 13)])
      .dayReview(for: .default, on: monday, today: monday)

    #expect(review.notDone.map(\.task.title) == ["tidy desk", "call bank"])
  }

  @Test("done tasks come in the order they were completed")
  func doneTasksComeInTheOrderTheyWereCompleted() {
    let review = LibraryState.replay(plannedMonday + [completed("t3", lamport: 13), completed("t2", lamport: 14)])
      .dayReview(for: .default, on: monday, today: monday)

    #expect(review.done.map(\.task.title) == ["write report", "tidy desk", "call bank"])
    #expect(review.notDone.isEmpty)
  }

  @Test("a task completed with its project counts as done on the day it was planned for")
  func aTaskCompletedWithItsProjectCountsAsDone() {
    let state = LibraryState.replay([
      projectCreated("p1", "Move house", lamport: 1), captured("t1", "pack", lamport: 2),
      moved("t1", to: "p1", lamport: 3), scheduled("t1", on: "2026-10-19", lamport: 4),
      projectCompleted("p1", lamport: 5),
    ])

    #expect(state.dayReview(for: .default, on: monday, today: monday).done.map(\.task.title) == ["pack"])
  }

  @Test("a task that is reopened is no longer done")
  func aTaskThatIsReopenedIsNoLongerDone() {
    let state = LibraryState.replay(plannedMonday + [reopened("t1", lamport: 13)])

    let review = state.dayReview(for: .default, on: monday, today: monday)

    #expect(review.done.isEmpty)
    #expect(!review.notDone.map(\.task.title).contains("write report"))
  }

  @Test("a dropped task is gone from the review")
  func aDroppedTaskIsGoneFromTheReview() {
    let review = LibraryState.replay(plannedMonday + [dropped("t2", lamport: 13)])
      .dayReview(for: .default, on: monday, today: monday)

    #expect(review.notDone.map(\.task.title) == ["tidy desk"])
  }

  @Test("another view's tasks are never reviewed")
  func anotherViewsTasksAreNeverReviewed() {
    let state = LibraryState.replay(plannedMonday + [viewCreated("work", "Work", lamport: 13)])

    let review = state.dayReview(for: ViewID("work"), on: monday, today: monday)

    #expect(review.done.isEmpty)
    #expect(review.notDone.isEmpty)
  }
}

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
      captured("t2", "tidy desk", lamport: 3), prioritized("t2", as: .optional, lamport: 4),
      scheduled("t1", on: "2026-10-19", lamport: 5), scheduled("t2", on: "2026-10-19", lamport: 6),
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

    let history = state.estimateHistory(ofProject: ProjectID("p1"))

    #expect(history == EstimateHistory(estimatedMinutes: 90, loggedMinutes: 135, taskCount: 2))
  }

  @Test("a project with nothing logged has no history")
  func aProjectWithNothingLoggedHasNoHistory() {
    let state = LibraryState.replay([
      projectCreated("p1", "Move house", lamport: 1), captured("t1", "pack books", lamport: 2),
      moved("t1", to: "p1", lamport: 3), estimated("t1", as: 30, lamport: 4),
    ])

    #expect(state.estimateHistory(ofProject: ProjectID("p1")) == nil)
  }
}
