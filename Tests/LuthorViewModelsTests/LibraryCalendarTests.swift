import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let monday = date("2026-10-19")

@MainActor
private func makeLibrary(_ events: [EventEnvelope] = []) -> LibraryViewModel {
  let library = LibraryViewModel(
    log: InMemoryEventLog(events), commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
    today: { monday })
  library.reload()
  return library
}

private let planned = [
  captured("t1", "call bank", lamport: 1), captured("t2", "pay tax", lamport: 1),
  scheduled("t1", on: "2026-10-21", lamport: 2), dueSet("t2", on: "2026-10-21", lamport: 2),
]

@MainActor
@Suite("When the calendar is shown")
struct LibraryCalendarTests {
  @Test("the rail has it between Today and Review")
  func theRailHasItBetweenTodayAndReview() {
    let sections = NavigationSection.allCases

    #expect(sections.firstIndex(of: .calendar) == sections.firstIndex(of: .today).map { $0 + 1 })
    #expect(sections.firstIndex(of: .review) == sections.firstIndex(of: .calendar).map { $0 + 1 })
  }

  @Test("it lists 60 days before today, today and 365 days after, marked where tasks are")
  func itListsTheDaysAroundToday() {
    let library = makeLibrary(planned)

    library.show(.calendar)

    #expect(library.calendarDays.count == 426)
    #expect(library.calendarDays.first?.date == monday.adding(days: -60))
    #expect(library.calendarDays.last?.date == monday.adding(days: 365))
    #expect(library.calendarDays.filter(\.hasTasks).map(\.date) == [date("2026-10-21")])
  }

  @Test("no day is picked at first, and the list of tasks is empty")
  func noDayIsPickedAtFirst() {
    let library = makeLibrary(planned)

    library.show(.calendar)

    #expect(library.calendarDate == nil)
    #expect(library.calendarEntries.isEmpty)
    #expect(library.tasks.isEmpty)
  }

  @Test("picking a day lists its tasks, and the keyboard walks through them")
  func pickingADayListsItsTasks() {
    let library = makeLibrary(planned)
    library.show(.calendar)

    library.showCalendarDay(date("2026-10-21"))

    #expect(library.calendarDate == date("2026-10-21"))
    #expect(library.tasks.map(\.title) == ["call bank", "pay tax"])
    library.moveSelection(by: 1)
    #expect(library.selectedTask?.title == "call bank")
  }

  @Test("picking another day drops the selection")
  func pickingAnotherDayDropsTheSelection() {
    let library = makeLibrary(planned)
    library.show(.calendar)
    library.showCalendarDay(date("2026-10-21"))
    library.selection = TaskID("t1")

    library.showCalendarDay(date("2026-10-22"))

    #expect(library.selection == nil)
    #expect(library.tasks.isEmpty)
  }

  @Test("the day stays picked when the rail comes back to the calendar")
  func theDayStaysPicked() {
    let library = makeLibrary(planned)
    library.show(.calendar)
    library.showCalendarDay(date("2026-10-21"))

    library.show(.today)
    library.show(.calendar)

    #expect(library.calendarDate == date("2026-10-21"))
    #expect(library.tasks.map(\.title) == ["call bank", "pay tax"])
  }

  @Test("a task completed from the list leaves the day, and its marks")
  func aCompletedTaskLeavesTheDay() {
    let library = makeLibrary(planned)
    library.show(.calendar)
    library.showCalendarDay(date("2026-10-21"))

    library.complete(TaskID("t1"))

    #expect(library.tasks.map(\.title) == ["pay tax"])
    #expect(library.calendarDays.first { $0.date == date("2026-10-21") }?.plannedCount == 0)
    #expect(library.calendarDays.first { $0.date == date("2026-10-21") }?.dueCount == 1)
  }

  @Test("planning a task for the picked day puts it in the list")
  func planningATaskPutsItInTheList() {
    let library = makeLibrary(planned + [captured("t3", "write report", lamport: 1)])
    library.show(.calendar)
    library.showCalendarDay(date("2026-10-22"))

    library.schedule(TaskID("t3"), on: date("2026-10-22"))

    #expect(library.tasks.map(\.title) == ["write report"])
  }

  @Test("the days follow the clock when a day passes")
  func theDaysFollowTheClock() {
    var day = monday
    let library = LibraryViewModel(
      log: InMemoryEventLog(planned), commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
      today: { day })
    library.reload()
    library.show(.calendar)

    day = date("2026-10-20")
    library.reload()

    #expect(library.calendarDays.first?.date == date("2026-10-20").adding(days: -60))
  }
}
