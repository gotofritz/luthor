import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

// Monday 2026-10-19 is the day the window is launched on.

private let weekly = RepeatRule(every: 1, unit: .week)

/// Captures "water plants" and gives it, on its card, a hard deadline today and a weekly repeat.
@MainActor
private func captureWeeklyRoutine(in library: LibraryViewModel) throws -> TaskID {
  library.capture("water plants")
  let task = try library.task("water plants")
  library.selection = task
  library.editCard(.task(task))
  library.saveCard(
    ofTask: task,
    TaskCardDraft(
      title: "water plants", priority: nil, estimate: nil,
      due: DueDate(date: date("2026-10-19"), isHard: true), notes: "", repeatRule: weekly))
  return task
}

@MainActor
@Suite("Given a task with a due date and a weekly repeat, when I complete it")
struct CompleteRepeatingFlowTests {
  @Test("the next one is in the Inbox with the date a week on, and a relaunch still has it")
  func theNextOneIsInTheInboxAWeekOn() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let library = launchApp(on: url)
    let task = try captureWeeklyRoutine(in: library)
    #expect(library.repeatRule(of: task) == weekly)

    library.complete(task)

    let relaunched = launchApp(on: url)
    let next = try relaunched.task("water plants")
    #expect(next != task)
    #expect(relaunched.tasks.map(\.title) == ["water plants"])
    #expect(relaunched.dueDate(of: next) == DueDate(date: date("2026-10-26"), isHard: true))
    #expect(relaunched.repeatRule(of: next) == weekly)
  }

  @Test("the completed one stays in Completed as history")
  func theCompletedOneStaysInCompleted() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let task = try captureWeeklyRoutine(in: library)

    library.complete(task)
    library.showCompleted = true

    #expect(library.completedTaskIDs == [task])
    #expect(library.tasks.count == 2)
  }

  @Test("completing it late still lands the next one after today")
  func completingItLateStillLandsAfterToday() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let early = launchApp(on: url)
    let task = try captureWeeklyRoutine(in: early)

    let late = launchApp(on: url, today: date("2026-11-04"))
    late.complete(task)

    let next = try late.task("water plants")
    #expect(late.dueDate(of: next) == DueDate(date: date("2026-11-09"), isHard: true))
  }
}

@MainActor
@Suite("Given a repeating task, when I skip it, stop it or give it up")
struct EndRepeatingFlowTests {
  @Test("Skip drops this one and leaves the next, listing the skipped one as dropped")
  func skipDropsThisOneAndLeavesTheNext() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let task = try captureWeeklyRoutine(in: library)

    library.skip(task)

    let next = try library.task("water plants")
    #expect(next != task)
    #expect(library.tasks.count == 1)
    library.showCompleted = true
    #expect(library.completedTaskIDs == [task])
    #expect(library.droppedTaskIDs == [task])
    #expect(library.dueDate(of: next)?.date == date("2026-10-26"))
  }

  @Test("Stop Repeating keeps the task and its due date, and completing it makes no next one")
  func stopRepeatingKeepsTheTask() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let task = try captureWeeklyRoutine(in: library)

    library.stopRepeating(task)
    #expect(library.repeatRule(of: task) == nil)
    #expect(library.dueDate(of: task)?.date == date("2026-10-19"))
    library.complete(task)

    #expect(library.tasks.isEmpty)
  }

  @Test("Drop Task and Send to Someday end the series")
  func dropAndSomedayEndTheSeries() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let dropped = try captureWeeklyRoutine(in: library)
    library.dropTask(dropped)
    #expect(library.tasks.isEmpty)

    let someday = try captureWeeklyRoutine(in: library)
    library.sendToSomeday(someday)
    #expect(library.repeatRule(of: someday) == nil)
    library.complete(someday)

    library.show(.priorities)
    library.togglePriority(.someday)
    #expect(library.tasks.isEmpty)
  }
}

@MainActor
@Suite("Given a task with no due date, when I give it a repeat")
struct RepeatWithoutDueDateFlowTests {
  @Test("it gets the day Today shows, as a target date")
  func itGetsTheDayTodayShows() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("pay rent")
    let task = try library.task("pay rent")
    library.showDay(date("2026-10-21"))

    library.setRepeat(task, to: RepeatRule(every: 1, unit: .month))

    #expect(library.dueDate(of: task) == DueDate(date: date("2026-10-21"), isHard: false))
  }
}
