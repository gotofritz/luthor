import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let monday = date("2026-10-19")

@MainActor
private func makeLibrary(
  _ events: [EventEnvelope] = [],
  view: ViewID = .default,
  today: CalendarDate = monday
) -> (LibraryViewModel, InMemoryEventLog) {
  let log = InMemoryEventLog(events)
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()), view: view, today: { today })
  library.reload()
  return (library, log)
}

/// Three clarified tasks: an A of 60 minutes, a B of 30 and a C with no estimate.
private let clarified = [
  captured("t1", "write report", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
  estimated("t1", as: 60, lamport: 3),
  captured("t2", "call bank", lamport: 4), prioritized("t2", as: .important, lamport: 5),
  estimated("t2", as: 30, lamport: 6),
  captured("t3", "tidy desk", lamport: 7), prioritized("t3", as: .optional, lamport: 8),
]

@MainActor
@Suite("When the window shows the day")
struct TodayShownViewModelTests {
  @Test("it starts on the day of the clock")
  func itStartsOnTheDayOfTheClock() {
    let (library, _) = makeLibrary()

    #expect(library.today == monday)
    #expect(library.planDate == monday)
  }

  @Test("Today lists the plan and then the candidates, so the keyboard walks through both")
  func todayListsThePlanThenTheCandidates() {
    let (library, _) = makeLibrary(clarified + [scheduled("t2", on: "2026-10-19", lamport: 9)])

    library.show(.today)

    #expect(library.section == .today)
    #expect(library.plan.entries.map(\.task.title) == ["call bank"])
    #expect(library.tasks.map(\.title) == ["call bank", "write report", "tidy desk"])
    #expect(library.nextActions == Set(library.tasks.map(\.id)))
  }

  @Test("the arrow keys move down through the plan into the candidates")
  func theArrowKeysMoveDownThroughThePlanIntoTheCandidates() {
    let (library, _) = makeLibrary(clarified + [scheduled("t2", on: "2026-10-19", lamport: 9)])
    library.show(.today)

    library.moveSelection(by: 1)
    library.moveSelection(by: 1)

    #expect(library.selection == TaskID("t1"))
  }

  @Test("showing the next, the previous day and today again")
  func showingTheNextThePreviousDayAndTodayAgain() {
    let (library, _) = makeLibrary()

    library.showNextDay()
    #expect(library.planDate == date("2026-10-20"))
    library.showPreviousDay()
    library.showPreviousDay()
    #expect(library.planDate == date("2026-10-18"))
    library.showToday()
    #expect(library.planDate == monday)
  }

  @Test("showing a day clears nothing from another day's plan")
  func showingADayClearsNothingFromAnotherDaysPlan() {
    let (library, _) = makeLibrary(clarified + [scheduled("t1", on: "2026-10-20", lamport: 9)])

    library.showDay(date("2026-10-20"))

    #expect(library.plan.entries.map(\.task.title) == ["write report"])
    library.showToday()
    #expect(library.plan.entries.isEmpty)
  }

  @Test("the settings of the view give the capacity")
  func theSettingsOfTheViewGiveTheCapacity() {
    let (library, _) = makeLibrary([settingChanged(.capacityMonday, to: "300", lamport: 1)])

    #expect(library.plan.capacity.availableMinutes == 300)
  }

  @Test("Waiting for lists the delegated tasks of the view with the clock deciding what is due")
  func waitingForListsTheDelegatedTasks() {
    let events = clarified + [delegated("t2", to: "Sam", followUp: "2026-10-20", lamport: 9)]

    let (onMonday, _) = makeLibrary(events)
    let (onTuesday, _) = makeLibrary(events, today: date("2026-10-20"))

    #expect(onMonday.waiting.map(\.task.title) == ["call bank"])
    #expect(onMonday.waiting.map(\.isFollowUpDue) == [false])
    #expect(onTuesday.waiting.map(\.isFollowUpDue) == [true])
  }
}

@MainActor
@Suite("When tasks are planned from the window")
struct PlanActionViewModelTests {
  @Test("adding a task puts it in the plan of the day shown")
  func addingATaskPutsItInThePlanOfTheDayShown() {
    let (library, log) = makeLibrary(clarified)
    library.showNextDay()

    library.addToPlan(TaskID("t1"))

    #expect(library.plan.entries.map(\.task.title) == ["write report"])
    #expect(log.events.last == scheduled("t1", on: "2026-10-20", id: "id-1", lamport: 9))
  }

  @Test("adding the selected task keeps it selected")
  func addingTheSelectedTaskKeepsItSelected() {
    let (library, _) = makeLibrary(clarified)
    library.show(.today)
    library.selection = TaskID("t1")

    library.addSelectedToPlan()

    #expect(library.plan.entries.map(\.task.title) == ["write report"])
    #expect(library.selection == TaskID("t1"))
  }

  @Test("removing a task from the plan makes it a candidate again")
  func removingATaskFromThePlanMakesItACandidateAgain() {
    let (library, _) = makeLibrary(clarified + [scheduled("t1", on: "2026-10-19", lamport: 9)])

    library.removeFromPlan(TaskID("t1"))

    #expect(library.plan.entries.isEmpty)
    #expect(library.plan.candidates.map(\.task.id).contains(TaskID("t1")))
  }

  @Test("removing the selected task from the plan")
  func removingTheSelectedTaskFromThePlan() {
    let (library, _) = makeLibrary(clarified + [scheduled("t1", on: "2026-10-19", lamport: 9)])
    library.selection = TaskID("t1")

    library.removeSelectedFromPlan()

    #expect(library.plan.entries.isEmpty)
  }

  @Test("moving a task earlier or later writes the whole order of the day")
  func movingATaskWritesTheWholeOrder() {
    let (library, log) = makeLibrary(
      clarified + [scheduled("t1", on: "2026-10-19", lamport: 9), scheduled("t2", on: "2026-10-19", lamport: 10)])

    library.moveInPlan(TaskID("t2"), by: -1)

    #expect(library.plan.entries.map(\.task.title) == ["call bank", "write report"])
    #expect(log.events.last == planOrdered(["t2", "t1"], on: "2026-10-19", id: "id-1", lamport: 11))
    library.moveInPlan(TaskID("t2"), by: 1)
    #expect(library.plan.entries.map(\.task.title) == ["write report", "call bank"])
  }

  @Test("a task cannot be moved past either end of the plan")
  func aTaskCannotBeMovedPastEitherEnd() {
    let (library, log) = makeLibrary(
      clarified + [scheduled("t1", on: "2026-10-19", lamport: 9), scheduled("t2", on: "2026-10-19", lamport: 10)])
    let before = log.events.count

    library.moveInPlan(TaskID("t1"), by: -1)
    library.moveInPlan(TaskID("t2"), by: 1)
    library.moveInPlan(TaskID("t3"), by: -1)

    #expect(log.events.count == before)
  }

  @Test("moving the selected task")
  func movingTheSelectedTask() {
    let (library, _) = makeLibrary(
      clarified + [scheduled("t1", on: "2026-10-19", lamport: 9), scheduled("t2", on: "2026-10-19", lamport: 10)])
    library.selection = TaskID("t2")

    library.moveSelectedInPlan(by: -1)

    #expect(library.plan.entries.map(\.task.title) == ["call bank", "write report"])
  }

  @Test("deferring a task moves it to the day after the one shown")
  func deferringATaskMovesItToTheDayAfterTheOneShown() {
    let (library, _) = makeLibrary(clarified + [scheduled("t1", on: "2026-10-19", lamport: 9)])

    library.deferToTomorrow(TaskID("t1"))

    #expect(library.plan.entries.isEmpty)
    library.showNextDay()
    #expect(library.plan.entries.map(\.task.title) == ["write report"])
  }

  @Test("deferring the selected task")
  func deferringTheSelectedTask() {
    let (library, _) = makeLibrary(clarified + [scheduled("t1", on: "2026-10-19", lamport: 9)])
    library.selection = TaskID("t1")

    library.deferSelected()

    #expect(library.plan.entries.isEmpty)
  }

  @Test("setting the capacity of the day shown")
  func settingTheCapacityOfTheDayShown() {
    let (library, _) = makeLibrary()

    library.setDayCapacity(minutes: 120)

    #expect(library.plan.capacity.availableMinutes == 120)
    library.setDayCapacity(minutes: nil)
    #expect(library.plan.capacity.availableMinutes == 480)
  }
}

@MainActor
@Suite("When a task is decided on from the plan")
struct DecideActionViewModelTests {
  static let planned = clarified + [scheduled("t1", on: "2026-10-19", lamport: 9)]

  @Test("delegating records who, since the day of the clock, and the follow-up date")
  func delegatingRecordsWhoSinceWhenAndTheFollowUp() {
    let (library, _) = makeLibrary(Self.planned)

    library.delegate(TaskID("t1"), to: "Sam", followUp: date("2026-10-23"))

    #expect(library.plan.entries.isEmpty)
    let expected = Delegation(to: "Sam", since: monday, followUpDate: date("2026-10-23"))
    #expect(library.waiting.map(\.delegation) == [expected])
  }

  @Test("delegating the selected task")
  func delegatingTheSelectedTask() {
    let (library, _) = makeLibrary(Self.planned)
    library.show(.today)
    library.selection = TaskID("t1")

    library.delegateSelected(to: "Sam", followUp: nil)

    #expect(library.waiting.map(\.task.title) == ["write report"])
  }

  @Test("a blank name delegates nothing")
  func aBlankNameDelegatesNothing() {
    let (library, _) = makeLibrary(Self.planned)

    library.delegate(TaskID("t1"), to: "  ", followUp: nil)

    #expect(library.waiting.isEmpty)
    #expect(library.plan.entries.map(\.task.title) == ["write report"])
  }

  @Test("reclaiming a task ends the wait")
  func reclaimingATaskEndsTheWait() {
    let (library, _) = makeLibrary(clarified + [delegated("t1", to: "Sam", lamport: 9)])

    library.reclaim(TaskID("t1"))

    #expect(library.waiting.isEmpty)
  }

  @Test("sending to someday takes the task off the plan and the candidates")
  func sendingToSomedayTakesTheTaskOffThePlanAndTheCandidates() {
    let (library, _) = makeLibrary(Self.planned)

    library.sendToSomeday(TaskID("t1"))

    #expect(library.plan.entries.isEmpty)
    #expect(!library.plan.candidates.map(\.task.id).contains(TaskID("t1")))
  }

  @Test("sending the selected task to someday")
  func sendingTheSelectedTaskToSomeday() {
    let (library, _) = makeLibrary(Self.planned)
    library.selection = TaskID("t1")

    library.sendSelectedToSomeday()

    #expect(library.plan.entries.isEmpty)
  }

  @Test("dropping a task removes it, and the selection moves on")
  func droppingATaskRemovesIt() {
    let (library, _) = makeLibrary(Self.planned)
    library.show(.today)
    library.selection = TaskID("t1")

    library.dropSelected()

    #expect(library.plan.entries.isEmpty)
    #expect(!library.plan.candidates.map(\.task.id).contains(TaskID("t1")))
    #expect(library.selection == TaskID("t2"))
  }

  @Test("dropping a task by ID")
  func droppingATaskByID() {
    let (library, log) = makeLibrary(Self.planned)

    library.dropTask(TaskID("t1"))

    #expect(log.events.last == dropped("t1", id: "id-1", lamport: 10))
  }
}

@MainActor
@Suite("When the clock is the system's")
struct SystemClockViewModelTests {
  @Test("the day is a real recent one")
  func theDayIsARealRecentOne() {
    #expect(CalendarDate.systemToday() >= date("2026-10-17"))
  }

  @Test("a window made without a clock starts on the day of the system")
  func aWindowMadeWithoutAClockStartsOnTheDayOfTheSystem() {
    let library = LibraryViewModel(
      log: InMemoryEventLog([]), commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()))

    #expect(library.today >= date("2026-10-17"))
  }
}
