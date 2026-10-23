import LuthorDomain
import LuthorTestSupport
import Testing

private let monday = date("2026-10-19")

/// "write report" (60m) was planned for Monday and completed, "call bank" (B, 30m) and "tidy desk" (C, no
/// estimate) were planned for Monday and are open, and "read mail" was never planned.
let plannedMonday = [
  captured("t1", "write report", lamport: 1), estimated("t1", as: 60, lamport: 2),
  captured("t2", "call bank", lamport: 3), estimated("t2", as: 30, lamport: 4),
  prioritized("t2", as: .important, lamport: 4),
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

  @Test("a task that is reopened is no longer done, but is planned for its day again")
  func aTaskThatIsReopenedIsNoLongerDone() {
    let state = LibraryState.replay(plannedMonday + [reopened("t1", lamport: 13)])

    let review = state.dayReview(for: .default, on: monday, today: monday)

    #expect(review.done.isEmpty)
    #expect(review.notDone.map(\.task.title).contains("write report"))
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

@Suite("When the estimate of a planned task changes during the day")
struct PlannedEstimateReplayTests {
  @Test("the review counts the task at the estimate it had when it was planned")
  func theReviewCountsTheOriginalEstimate() {
    let state = LibraryState.replay(plannedMonday + [estimated("t2", as: 45, lamport: 14)])

    let review = state.dayReview(for: .default, on: monday, today: monday)

    #expect(review.done.map(\.minutes) == [60])
    #expect(review.notDone.map(\.minutes).first == 30)
  }

  @Test("a task planned with no estimate stays unestimated however it is estimated later")
  func anUnestimatedTaskStaysUnestimated() {
    let state = LibraryState.replay(plannedMonday + [estimated("t3", as: 20, lamport: 13)])

    let review = state.dayReview(for: .default, on: monday, today: monday)
    let tidy = review.notDone.first { $0.task.id == TaskID("t3") }

    #expect(tidy?.isUnestimated == true)
    #expect(tidy?.minutes == 5)
  }
}

@Suite("When a planned task is lengthened during the day")
struct CurrentLengthReplayTests {
  @Test("the review keeps the first estimate and also has the length it has now")
  func theReviewHasBothLengths() {
    let state = LibraryState.replay(plannedMonday + [estimated("t2", as: 90, lamport: 13)])

    let notDone = state.dayReview(for: .default, on: monday, today: monday).notDone
    let bank = notDone.first { $0.task.id == TaskID("t2") }

    #expect(bank?.minutes == 30)
    #expect(bank?.currentMinutes == 90)
  }
}
