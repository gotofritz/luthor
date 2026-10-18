import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

private let weekly = RepeatRule(every: 1, unit: .week)
private let monday = date("2026-10-19")
private let friday = date("2026-10-23")
private let nextID = TaskID.recurring(after: TaskID("t1")).rawValue

/// A weekly task due on Monday 2026-10-19; the lamport counter is 3.
private let routine = [
  captured("t1", "water plants", lamport: 1),
  dueSet("t1", on: "2026-10-19", lamport: 2),
  repeatSet("t1", weekly, lamport: 3),
]

@Suite("When a repeat is set by command")
struct SetRepeatCommandTests {
  static let plain = [captured("t1", "water plants", lamport: 1), dueSet("t1", on: "2026-10-19", lamport: 2)]

  @Test("it writes one TaskRepeatSet")
  func itWritesOneTaskRepeatSet() throws {
    let events = try makeCommands().setRepeat(taskID: TaskID("t1"), to: weekly, dueIfNone: friday, log: Self.plain)

    #expect(events == [repeatSet("t1", weekly, id: "id-1", lamport: 3)])
  }

  @Test("a task with no due date is given the day passed in, as a target date, first")
  func aTaskWithNoDueDateIsGivenOne() throws {
    let log = [captured("t1", "water plants", lamport: 1)]

    let events = try makeCommands().setRepeat(taskID: TaskID("t1"), to: weekly, dueIfNone: friday, log: log)

    #expect(
      events == [
        dueSet("t1", on: "2026-10-23", hard: false, id: "id-1", lamport: 2),
        repeatSet("t1", weekly, id: "id-2", lamport: 3),
      ])
  }

  @Test("a task that has a due date keeps it, whatever the day passed in")
  func aTaskThatHasADueDateKeepsIt() throws {
    let events = try makeCommands().setRepeat(taskID: TaskID("t1"), to: weekly, dueIfNone: friday, log: Self.plain)

    #expect(events.count == 1)
  }

  @Test("setting the rule the task has writes nothing")
  func settingTheRuleTheTaskHasWritesNothing() throws {
    #expect(try makeCommands().setRepeat(taskID: TaskID("t1"), to: weekly, dueIfNone: friday, log: routine) == [])
  }

  @Test("the rule the task has but no due date still gets the due date")
  func theRuleTheTaskHasButNoDueDateStillGetsTheDueDate() throws {
    let log = [captured("t1", "water plants", lamport: 1), repeatSet("t1", weekly, lamport: 2)]

    let events = try makeCommands().setRepeat(taskID: TaskID("t1"), to: weekly, dueIfNone: friday, log: log)

    #expect(events == [dueSet("t1", on: "2026-10-23", hard: false, id: "id-1", lamport: 3)])
  }

  @Test("changing the rule writes the new one")
  func changingTheRuleWritesTheNewOne() throws {
    let daily = RepeatRule(every: 1, unit: .day)

    let events = try makeCommands().setRepeat(taskID: TaskID("t1"), to: daily, dueIfNone: friday, log: routine)

    #expect(events == [repeatSet("t1", daily, id: "id-1", lamport: 4)])
  }

  @Test("clearing it writes a TaskRepeatSet with no rule, and nothing for a task that repeats not")
  func clearingItWritesATaskRepeatSetWithNoRule() throws {
    let events = try makeCommands().setRepeat(taskID: TaskID("t1"), to: nil, dueIfNone: friday, log: routine)

    #expect(events == [repeatSet("t1", nil, id: "id-1", lamport: 4)])
    #expect(try makeCommands().setRepeat(taskID: TaskID("t1"), to: nil, dueIfNone: friday, log: Self.plain) == [])
  }

  @Test("clearing it does not give a task a due date")
  func clearingItDoesNotGiveATaskADueDate() throws {
    let events = try makeCommands().setRepeat(
      taskID: TaskID("t1"), to: nil, dueIfNone: friday, log: [captured("t1", "water plants", lamport: 1)])

    #expect(events == [])
  }

  @Test("a task that is not open is refused")
  func aTaskThatIsNotOpenIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().setRepeat(taskID: TaskID("t9"), to: weekly, dueIfNone: friday, log: Self.plain)
    }
  }
}

@Suite("When a repeating task is completed by command")
struct CompleteRepeatingCommandTests {
  @Test("it writes the completion, then the next task with the next due date")
  func itWritesTheCompletionThenTheNextTask() throws {
    let events = try makeCommands().complete(taskID: TaskID("t1"), today: monday, log: routine)

    #expect(
      events == [
        completed("t1", id: "id-1", lamport: 4),
        recurred("t1", as: nextID, due: "2026-10-26", id: "id-2", lamport: 5),
      ])
  }

  @Test("completed late, the next due date is still after today")
  func completedLateTheNextDueDateIsStillAfterToday() throws {
    let events = try makeCommands().complete(taskID: TaskID("t1"), today: date("2026-11-04"), log: routine)

    #expect(events.last == recurred("t1", as: nextID, due: "2026-11-09", id: "id-2", lamport: 5))
  }

  @Test("counted from completion, the next due date is a week after the day it is done")
  func countedFromCompletionTheNextDueDateIsAWeekAfterTheDayItIsDone() throws {
    let after = RepeatRule(every: 1, unit: .week, afterCompletion: true)
    let log = [
      captured("t1", "water plants", lamport: 1), dueSet("t1", on: "2026-10-19", lamport: 2), repeatSet("t1", after),
    ]

    let events = try makeCommands().complete(taskID: TaskID("t1"), today: friday, log: log)

    #expect(events.last == recurred("t1", as: nextID, due: "2026-10-30", id: "id-2", lamport: 5))
  }

  @Test("without the day, it counts as done on the due date")
  func withoutTheDayItCountsAsDoneOnTheDueDate() throws {
    let events = try makeCommands().complete(taskID: TaskID("t1"), log: routine)

    #expect(events.last == recurred("t1", as: nextID, due: "2026-10-26", id: "id-2", lamport: 5))
  }

  @Test("a repeating task with no due date counts from the day it is done")
  func aRepeatingTaskWithNoDueDateCountsFromTheDayItIsDone() throws {
    let log = [captured("t1", "water plants", lamport: 1), repeatSet("t1", weekly, lamport: 2)]

    let events = try makeCommands().complete(taskID: TaskID("t1"), today: friday, log: log)

    #expect(events.last == recurred("t1", as: nextID, due: "2026-10-30", id: "id-2", lamport: 4))
  }

  @Test("a task that does not repeat writes only its completion")
  func aTaskThatDoesNotRepeatWritesOnlyItsCompletion() throws {
    let log = [captured("t1", "pay tax", lamport: 1), dueSet("t1", on: "2026-10-19", lamport: 2)]

    let events = try makeCommands().complete(taskID: TaskID("t1"), today: monday, log: log)

    #expect(events == [completed("t1", id: "id-1", lamport: 3)])
  }

  @Test("a task whose next task exists already writes only its completion")
  func aTaskWhoseNextTaskExistsAlreadyWritesOnlyItsCompletion() throws {
    let log =
      routine + [
        completed("t1", lamport: 4), recurred("t1", as: nextID, due: "2026-10-26", lamport: 5),
        reopened("t1", lamport: 6),
      ]

    let events = try makeCommands().complete(taskID: TaskID("t1"), today: monday, log: log)

    #expect(events == [completed("t1", id: "id-1", lamport: 7)])
  }
}

@Suite("When a repeating task is skipped by command")
struct SkipRepeatingCommandTests {
  @Test("it writes the next task, then drops this one")
  func itWritesTheNextTaskThenDropsThisOne() throws {
    let events = try makeCommands().skip(taskID: TaskID("t1"), today: monday, log: routine)

    #expect(
      events == [
        recurred("t1", as: nextID, due: "2026-10-26", id: "id-1", lamport: 4),
        dropped("t1", id: "id-2", lamport: 5),
      ])
  }

  @Test("skipping late still lands after today")
  func skippingLateStillLandsAfterToday() throws {
    let events = try makeCommands().skip(taskID: TaskID("t1"), today: date("2026-11-04"), log: routine)

    #expect(events.first == recurred("t1", as: nextID, due: "2026-11-09", id: "id-1", lamport: 4))
  }

  @Test("a task that does not repeat is refused")
  func aTaskThatDoesNotRepeatIsRefused() {
    #expect(throws: CommandError.notRepeating(TaskID("t1"))) {
      try makeCommands().skip(taskID: TaskID("t1"), today: monday, log: [captured("t1", "pay tax", lamport: 1)])
    }
  }

  @Test("a task that is not open is refused")
  func aTaskThatIsNotOpenIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().skip(taskID: TaskID("t9"), today: monday, log: routine)
    }
  }

  @Test("a task whose next task exists already is only dropped")
  func aTaskWhoseNextTaskExistsAlreadyIsOnlyDropped() throws {
    let log =
      routine + [
        completed("t1", lamport: 4), recurred("t1", as: nextID, due: "2026-10-26", lamport: 5),
        reopened("t1", lamport: 6),
      ]

    let events = try makeCommands().skip(taskID: TaskID("t1"), today: monday, log: log)

    #expect(events == [dropped("t1", id: "id-1", lamport: 7)])
  }
}

@Suite("When a repeating task is given up by command")
struct EndRepeatingCommandTests {
  @Test("dropping it writes only the drop, so the series ends")
  func droppingItWritesOnlyTheDrop() throws {
    #expect(try makeCommands().drop(taskID: TaskID("t1"), log: routine) == [dropped("t1", id: "id-1", lamport: 4)])
  }

  @Test("sending it to someday clears the repeat, so the series ends")
  func sendingItToSomedayClearsTheRepeat() throws {
    let events = try makeCommands().sendToSomeday(taskID: TaskID("t1"), log: routine)

    #expect(
      events == [
        prioritized("t1", as: .someday, id: "id-1", lamport: 4),
        repeatSet("t1", nil, id: "id-2", lamport: 5),
      ])
  }

  @Test("sending a task that does not repeat to someday writes no repeat event")
  func sendingATaskThatDoesNotRepeatToSomedayWritesNoRepeatEvent() throws {
    let events = try makeCommands().sendToSomeday(
      taskID: TaskID("t1"), log: [captured("t1", "pay tax", lamport: 1)])

    #expect(events == [prioritized("t1", as: .someday, id: "id-1", lamport: 2)])
  }
}
