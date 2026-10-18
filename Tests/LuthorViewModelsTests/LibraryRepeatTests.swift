import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let monday = date("2026-10-19")
private let weekly = RepeatRule(every: 1, unit: .week)

@MainActor
private func makeLibrary(_ events: [EventEnvelope] = []) -> (LibraryViewModel, InMemoryEventLog) {
  let log = InMemoryEventLog(events)
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()), today: { monday })
  library.reload()
  return (library, log)
}

/// A weekly task due today.
private let routine = [
  captured("t1", "water plants", lamport: 1),
  dueSet("t1", on: "2026-10-19", lamport: 2),
  repeatSet("t1", weekly, lamport: 3),
]

private let nextID = TaskID.recurring(after: TaskID("t1"))

@MainActor
@Suite("When a repeating task is completed in the window")
struct CompleteRepeatingViewModelTests {
  @Test("the next task is written with the due date a week on, and shows in the inbox")
  func theNextTaskIsWrittenAndShown() {
    let (library, log) = makeLibrary(routine)

    library.complete(TaskID("t1"))

    #expect(
      log.events.suffix(2) == [
        completed("t1", id: "id-1", lamport: 4),
        recurred("t1", as: nextID.rawValue, due: "2026-10-26", id: "id-2", lamport: 5),
      ])
    #expect(library.tasks.map(\.id) == [nextID])
    #expect(library.dueDate(of: nextID) == DueDate(date: date("2026-10-26"), isHard: true))
    #expect(library.repeatRule(of: nextID) == weekly)
  }

  @Test("a task that does not repeat writes only its completion")
  func aTaskThatDoesNotRepeatWritesOnlyItsCompletion() {
    let (library, log) = makeLibrary([captured("t1", "pay tax", lamport: 1)])

    library.complete(TaskID("t1"))

    #expect(log.events == [captured("t1", "pay tax", lamport: 1), completed("t1", id: "id-1", lamport: 2)])
  }
}

@MainActor
@Suite("When a repeat is set or ended in the window")
struct SetRepeatViewModelTests {
  @Test("a task with no due date is given the day Today shows, as a target date")
  func aTaskWithNoDueDateIsGivenTheDayTodayShows() {
    let (library, log) = makeLibrary([captured("t1", "water plants", lamport: 1)])
    library.showDay(date("2026-10-21"))

    library.setRepeat(TaskID("t1"), to: weekly)

    #expect(
      log.events.suffix(2) == [
        dueSet("t1", on: "2026-10-21", hard: false, id: "id-1", lamport: 2),
        repeatSet("t1", weekly, id: "id-2", lamport: 3),
      ])
    #expect(library.repeatRule(of: TaskID("t1")) == weekly)
  }

  @Test("stopping the repeat clears the rule and keeps the due date")
  func stoppingTheRepeatClearsTheRule() {
    let (library, log) = makeLibrary(routine)

    library.stopRepeating(TaskID("t1"))

    #expect(log.events.last == repeatSet("t1", nil, id: "id-1", lamport: 4))
    #expect(library.repeatRule(of: TaskID("t1")) == nil)
    #expect(library.dueDate(of: TaskID("t1")) != nil)
  }

  @Test("skipping drops the task and leaves the next one")
  func skippingDropsTheTaskAndLeavesTheNextOne() {
    let (library, log) = makeLibrary(routine)

    library.skip(TaskID("t1"))

    #expect(
      log.events.suffix(2) == [
        recurred("t1", as: nextID.rawValue, due: "2026-10-26", id: "id-1", lamport: 4),
        dropped("t1", id: "id-2", lamport: 5),
      ])
    #expect(library.tasks.map(\.id) == [nextID])
  }

  @Test("skipping the selected task selects the next one")
  func skippingTheSelectedTaskSelectsTheNextOne() {
    let (library, _) = makeLibrary(routine)
    library.selection = TaskID("t1")

    library.skipSelected()

    #expect(library.selection == nextID)
  }

  @Test("giving a task up ends the series: dropping writes no next task, and someday clears the rule")
  func givingATaskUpEndsTheSeries() {
    let (dropping, droppingLog) = makeLibrary(routine)
    dropping.dropTask(TaskID("t1"))
    let (someday, somedayLog) = makeLibrary(routine)
    someday.sendToSomeday(TaskID("t1"))

    #expect(droppingLog.events.suffix(1) == [dropped("t1", id: "id-1", lamport: 4)])
    #expect(somedayLog.events.suffix(1) == [repeatSet("t1", nil, id: "id-2", lamport: 5)])
    #expect(someday.repeatRule(of: TaskID("t1")) == nil)
  }
}

@MainActor
@Suite("When the repeat is edited on a card")
struct RepeatCardViewModelTests {
  private func draft(_ rule: RepeatRule?, due: DueDate?) -> TaskCardDraft {
    TaskCardDraft(
      title: "water plants", priority: nil, estimate: nil, due: due, notes: "", repeatRule: rule)
  }

  @Test("OK keeps a repeat with its due date, and writes nothing when it is unchanged")
  func okKeepsARepeat() {
    let (library, log) = makeLibrary([captured("t1", "water plants", lamport: 1)])
    let due = DueDate(date: date("2026-10-23"), isHard: false)

    library.editCard(.task(TaskID("t1")))
    library.saveCard(ofTask: TaskID("t1"), draft(weekly, due: due))
    let written = log.events.count
    library.editCard(.task(TaskID("t1")))
    library.saveCard(ofTask: TaskID("t1"), draft(weekly, due: due))

    #expect(library.repeatRule(of: TaskID("t1")) == weekly)
    #expect(library.dueDate(of: TaskID("t1")) == due)
    #expect(log.events.count == written)
  }

  @Test("a repeat with no due date is given the day Today shows")
  func aRepeatWithNoDueDateIsGivenTheDayTodayShows() {
    let (library, _) = makeLibrary([captured("t1", "water plants", lamport: 1)])

    library.editCard(.task(TaskID("t1")))
    library.saveCard(ofTask: TaskID("t1"), draft(weekly, due: nil))

    #expect(library.dueDate(of: TaskID("t1")) == DueDate(date: monday, isHard: false))
  }

  @Test("OK with no repeat on a card that had one stops it")
  func okWithNoRepeatStopsIt() {
    let (library, _) = makeLibrary(routine)

    library.editCard(.task(TaskID("t1")))
    library.saveCard(ofTask: TaskID("t1"), draft(nil, due: DueDate(date: monday, isHard: true)))

    #expect(library.repeatRule(of: TaskID("t1")) == nil)
  }
}

@Suite("When a repeat is described")
struct RepeatSummaryTests {
  @Test(
    "the card says how often",
    arguments: [
      (RepeatRule(every: 1, unit: .day), "Repeats every day"),
      (RepeatRule(every: 3, unit: .day), "Repeats every 3 days"),
      (RepeatRule(every: 1, unit: .week), "Repeats every week"),
      (RepeatRule(every: 1, unit: .week, weekdays: [.thursday, .monday]), "Repeats every week on Mon, Thu"),
      (RepeatRule(every: 2, unit: .week, weekdays: [.monday]), "Repeats every 2 weeks on Mon"),
      (RepeatRule(every: 1, unit: .month), "Repeats every month"),
      (RepeatRule(every: 2, unit: .year), "Repeats every 2 years"),
      (RepeatRule(every: 1, unit: .week, afterCompletion: true), "Repeats 1 week after it is done"),
      (RepeatRule(every: 3, unit: .day, afterCompletion: true), "Repeats 3 days after it is done"),
    ])
  func theCardSaysHowOften(rule: RepeatRule, summary: String) {
    #expect(rule.summary == summary)
  }
}
