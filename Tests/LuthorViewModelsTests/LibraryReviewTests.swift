import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let monday = date("2026-10-19")

@MainActor
private func makeLibrary(
  _ events: [EventEnvelope] = [],
  today: CalendarDate = monday
) -> (LibraryViewModel, InMemoryEventLog) {
  let log = InMemoryEventLog(events)
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()), view: .default, today: { today })
  library.reload()
  return (library, log)
}

/// Monday's plan: "write report" (60m) is done, "call bank" (30m) and "tidy desk" are not.
private let plannedMonday = [
  captured("t1", "write report", lamport: 1), estimated("t1", as: 60, lamport: 2),
  captured("t2", "call bank", lamport: 3), estimated("t2", as: 30, lamport: 4),
  prioritized("t2", as: .important, lamport: 4),
  captured("t3", "tidy desk", lamport: 5), prioritized("t3", as: .optional, lamport: 6),
  scheduled("t1", on: "2026-10-19", lamport: 7), scheduled("t2", on: "2026-10-19", lamport: 8),
  scheduled("t3", on: "2026-10-19", lamport: 9), completed("t1", lamport: 10),
]

@MainActor
@Suite("When the window shows the review of a day")
struct ReviewShownViewModelTests {
  @Test("the review is of the day shown, and follows it when the day changes")
  func theReviewIsOfTheDayShown() {
    let (library, _) = makeLibrary(plannedMonday)

    #expect(library.review.date == monday)
    #expect(library.review.done.map(\.task.title) == ["write report"])
    library.showNextDay()
    #expect(library.review.date == date("2026-10-20"))
    #expect(library.review.done.isEmpty)
    library.showPreviousDay()
    #expect(library.review.notDone.map(\.task.title) == ["call bank", "tidy desk"])
  }

  @Test("the review lists the tasks not done, so the keyboard decides on them")
  func theReviewListsTheTasksNotDone() {
    let (library, _) = makeLibrary(plannedMonday)

    library.show(.review)

    #expect(library.section == .review)
    #expect(library.tasks.map(\.title) == ["call bank", "tidy desk"])
    #expect(library.nextActions == Set(library.tasks.map(\.id)))
  }

  @Test("deciding on the selected task takes it off the review and selects the one that takes its place")
  func decidingOnTheSelectedTask() {
    let (library, _) = makeLibrary(plannedMonday)
    library.show(.review)
    library.moveSelection(by: 1)

    library.sendSelectedToSomeday()

    #expect(library.review.notDone.map(\.task.title) == ["tidy desk"])
    #expect(library.selection == TaskID("t3"))
  }

  @Test("deferring a task of the review plans it for the day after the one reviewed")
  func deferringATaskOfTheReview() {
    let (library, _) = makeLibrary(plannedMonday)
    library.show(.review)

    library.deferToTomorrow(TaskID("t2"))

    #expect(library.review.notDone.map(\.task.title) == ["tidy desk"])
    library.showNextDay()
    #expect(library.plan.entries.map(\.task.title) == ["call bank"])
  }
}

@MainActor
@Suite("When a task of the review is planned for another day")
struct ScheduleAnotherDayViewModelTests {
  @Test("it leaves the review and is planned for that day, and nothing is duplicated")
  func itLeavesTheReviewAndIsPlannedForThatDay() {
    let (library, _) = makeLibrary(plannedMonday)
    library.show(.review)

    library.schedule(TaskID("t2"), on: date("2026-10-23"))

    #expect(library.review.notDone.map(\.task.title) == ["tidy desk"])
    library.showDay(date("2026-10-23"))
    #expect(library.plan.entries.map(\.task.id) == [TaskID("t2")])
  }
}

@MainActor
@Suite("When time is logged from the window")
struct LogTimeViewModelTests {
  @Test("time logged for a task lands on the day shown")
  func timeLoggedForATaskLandsOnTheDayShown() {
    let (library, log) = makeLibrary(plannedMonday)

    library.logTime(TaskID("t1"), minutes: 90)

    #expect(log.events.last == timeLogged("t1", on: "2026-10-19", minutes: 90, id: "id-1", lamport: 11))
    #expect(library.review.done.map(\.loggedMinutes) == [90])
    #expect(library.review.loggedMinutes == 90)
  }

  @Test("time can be logged for a day that is over")
  func timeCanBeLoggedForADayThatIsOver() {
    let (library, log) = makeLibrary(plannedMonday, today: date("2026-10-21"))
    library.showDay(monday)

    library.logTime(TaskID("t2"), minutes: 20)

    #expect(log.events.last == timeLogged("t2", on: "2026-10-19", minutes: 20, id: "id-1", lamport: 11))
  }

  @Test("clearing the time of a task takes it off the day")
  func clearingTheTimeOfATask() {
    let (library, _) = makeLibrary(plannedMonday + [timeLogged("t1", on: "2026-10-19", minutes: 90, lamport: 11)])

    library.logTime(TaskID("t1"), minutes: nil)

    #expect(library.review.done.map(\.loggedMinutes) == [nil])
  }

  @Test("unplanned time lands on the current view and the day shown")
  func unplannedTimeLandsOnTheCurrentViewAndTheDayShown() {
    let (library, log) = makeLibrary(plannedMonday)

    library.logUnplannedTime(minutes: 25)

    #expect(log.events.last == unplannedTimeLogged(25, on: "2026-10-19", id: "id-1", lamport: 11))
    #expect(library.review.unplannedMinutes == 25)
  }

  @Test("a task that does not exist writes nothing")
  func aTaskThatDoesNotExistWritesNothing() {
    let (library, log) = makeLibrary(plannedMonday)

    library.logTime(TaskID("t9"), minutes: 20)

    #expect(log.events.count == plannedMonday.count)
    #expect(library.errorMessage == nil)
  }
}

@MainActor
@Suite("When the day is reviewed from the window")
struct ReviewDayViewModelTests {
  @Test("reviewing the day writes the note for the day shown")
  func reviewingTheDayWritesTheNote() {
    let (library, log) = makeLibrary(plannedMonday)

    library.reviewDay(note: "Too many calls")

    #expect(log.events.last == dayReviewed(on: "2026-10-19", note: "Too many calls", id: "id-1", lamport: 11))
    #expect(library.review.isReviewed)
    #expect(library.review.note == "Too many calls")
  }

  @Test("another day is not reviewed by it")
  func anotherDayIsNotReviewedByIt() {
    let (library, _) = makeLibrary(plannedMonday)

    library.reviewDay(note: "Too many calls")
    library.showNextDay()

    #expect(!library.review.isReviewed)
  }
}

@MainActor
@Suite("When tasks are left over from earlier days")
struct CarryOverViewModelTests {
  private let leftOver = [
    captured("t1", "write report", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
    captured("t2", "call bank", lamport: 3), prioritized("t2", as: .important, lamport: 4),
    scheduled("t1", on: "2026-10-19", lamport: 5),
  ]

  @Test("they are listed before the plan and the candidates, so the keyboard walks through them first")
  func theyAreListedBeforeThePlanAndTheCandidates() {
    let (library, _) = makeLibrary(leftOver, today: date("2026-10-20"))

    library.show(.today)

    #expect(library.carryOver.map(\.entry.task.title) == ["write report"])
    #expect(library.tasks.map(\.title) == ["write report", "call bank"])
    #expect(library.nextActions == Set(library.tasks.map(\.id)))
  }

  @Test("there are none on the day they were planned for")
  func thereAreNoneOnTheDayTheyWerePlannedFor() {
    let (library, _) = makeLibrary(leftOver)

    #expect(library.carryOver.isEmpty)
  }

  @Test("adding a left over task to the plan plans it for the day shown and takes it off the leftovers")
  func addingALeftOverTaskToThePlan() {
    let (library, _) = makeLibrary(leftOver, today: date("2026-10-20"))
    library.show(.today)

    library.addToPlan(TaskID("t1"))

    #expect(library.carryOver.isEmpty)
    #expect(library.plan.entries.map(\.task.title) == ["write report"])
  }

  @Test("sending a left over task back to the list makes it a candidate")
  func sendingALeftOverTaskBackToTheList() {
    let (library, _) = makeLibrary(leftOver, today: date("2026-10-20"))
    library.show(.today)

    library.removeFromPlan(TaskID("t1"))

    #expect(library.carryOver.isEmpty)
    #expect(library.plan.candidates.map(\.task.title) == ["write report", "call bank"])
  }
}

@MainActor
@Suite("When the window shows the history of estimates")
struct EstimateHistoryViewModelTests {
  @Test("a task shows its estimate against the minutes logged")
  func aTaskShowsItsEstimateAgainstTheMinutesLogged() {
    let (library, _) = makeLibrary(plannedMonday + [timeLogged("t1", on: "2026-10-19", minutes: 90, lamport: 11)])

    #expect(
      library.estimateHistory(ofTask: TaskID("t1"))
        == EstimateHistory(estimatedMinutes: 60, loggedMinutes: 90, taskCount: 1))
    #expect(library.estimateHistory(ofTask: TaskID("t2")) == nil)
  }

  @Test("a project shows the history of its tasks")
  func aProjectShowsTheHistoryOfItsTasks() {
    let (library, _) = makeLibrary([
      projectCreated("p1", "Move house", lamport: 1), captured("t1", "pack books", lamport: 2),
      moved("t1", to: "p1", lamport: 3), estimated("t1", as: 30, lamport: 4),
      timeLogged("t1", on: "2026-10-19", minutes: 45, lamport: 5),
    ])

    #expect(
      library.estimateHistory(ofProject: TaskID("p1"))
        == EstimateHistory(estimatedMinutes: 30, loggedMinutes: 45, taskCount: 1))
  }
}
