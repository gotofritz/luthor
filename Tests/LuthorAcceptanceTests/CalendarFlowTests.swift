import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

// Monday 2026-10-19 is the day the window is launched on.

@MainActor
@Suite("Given the navigation rail, when I pick the calendar")
struct CalendarPlaceFlowTests {
  @Test("the calendar is a place on the rail, and its first column lists the days around today")
  func theCalendarIsAPlaceOnTheRail() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))

    library.show(.calendar)

    #expect(NavigationSection.allCases.contains(.calendar))
    #expect(library.section == .calendar)
    #expect(library.calendarDays.first?.date == date("2026-08-20"))
    #expect(library.calendarDays.last?.date == date("2027-10-19"))
    #expect(library.calendarDays.contains { $0.date == date("2026-10-19") })
    #expect(library.calendarDays.allSatisfy { !$0.hasTasks })
    #expect(library.calendarDate == nil)
    #expect(library.tasks.isEmpty)
  }
}

@MainActor
@Suite("Given tasks planned for days and due on others, when I look at the calendar")
struct CalendarMarksFlowTests {
  @Test("a mark shows which days have tasks planned, or due, and a relaunch still shows them")
  func marksShowWhichDaysHaveTasks() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let library = launchApp(on: url)
    library.capture("call bank")
    library.capture("pay tax")
    let bank = try library.task("call bank")
    let tax = try library.task("pay tax")

    library.schedule(bank, on: date("2026-10-21"))
    library.setDue(tax, to: date("2026-10-23"), isHard: true)
    library.show(.calendar)

    let marked = library.calendarDays.filter(\.hasTasks)
    #expect(marked.map(\.date) == [date("2026-10-21"), date("2026-10-23")])
    #expect(marked.map(\.plannedCount) == [1, 0])
    #expect(marked.map(\.dueCount) == [0, 1])
    let relaunched = launchApp(on: url)
    relaunched.show(.calendar)
    #expect(relaunched.calendarDays.filter(\.hasTasks).map(\.date) == [date("2026-10-21"), date("2026-10-23")])
  }

  @Test("completing a task takes its marks away")
  func completingATaskTakesItsMarksAway() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("call bank")
    let bank = try library.task("call bank")
    library.schedule(bank, on: date("2026-10-21"))
    library.show(.calendar)
    #expect(library.calendarDays.contains { $0.hasTasks })

    library.complete(bank)

    #expect(!library.calendarDays.contains { $0.hasTasks })
  }

  @Test("another view's tasks leave no marks")
  func anotherViewsTasksLeaveNoMarks() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let work = try library.createView("Work")
    library.capture("ship release")
    let release = try library.task("ship release")
    library.schedule(release, on: date("2026-10-21"))
    library.show(.calendar)
    #expect(library.calendarDays.contains { $0.hasTasks })

    library.showView(.default)
    library.show(.calendar)
    #expect(!library.calendarDays.contains { $0.hasTasks })
    library.showView(work)
    library.show(.calendar)
    #expect(library.calendarDays.contains { $0.hasTasks })
  }
}

@MainActor
@Suite("Given a day with tasks, when I click it on the calendar")
struct CalendarDayFlowTests {
  @Test("the next column lists all the tasks of that day, planned first and then due")
  func theNextColumnListsAllTheTasksOfThatDay() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("pay tax")
    library.capture("call bank")
    library.capture("write report")
    let tax = try library.task("pay tax")
    let bank = try library.task("call bank")
    library.schedule(bank, on: date("2026-10-21"))
    library.setDue(tax, to: date("2026-10-21"), isHard: true)
    library.show(.calendar)

    library.showCalendarDay(date("2026-10-21"))

    #expect(library.calendarDate == date("2026-10-21"))
    #expect(library.calendarEntries.map(\.task.title) == ["call bank", "pay tax"])
    #expect(library.calendarEntries.map(\.isPlanned) == [true, false])
    #expect(library.calendarEntries.map(\.due) == [nil, DueDate(date: date("2026-10-21"), isHard: true)])
    #expect(library.tasks.map(\.title) == ["call bank", "pay tax"])
  }

  @Test("clicking a task opens its card in the column after, and another day lists other tasks")
  func clickingATaskOpensItsCard() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("call bank")
    library.capture("pay tax")
    let bank = try library.task("call bank")
    let tax = try library.task("pay tax")
    library.schedule(bank, on: date("2026-10-21"))
    library.schedule(tax, on: date("2026-10-22"))
    library.show(.calendar)
    library.showCalendarDay(date("2026-10-21"))

    library.selection = bank
    #expect(library.selectedTask?.title == "call bank")

    library.showCalendarDay(date("2026-10-22"))
    #expect(library.tasks.map(\.title) == ["pay tax"])
    #expect(library.selectedTask == nil)
  }

  @Test("a day with nothing lists nothing")
  func aDayWithNothingListsNothing() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.show(.calendar)

    library.showCalendarDay(date("2026-10-20"))

    #expect(library.calendarEntries.isEmpty)
    #expect(library.tasks.isEmpty)
  }
}
