import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a due date is set by command")
struct DueDateCommandTests {
  static let log = [captured("t1", "pay tax", lamport: 1)]

  @Test("it writes one TaskDueSet")
  func itWritesOneTaskDueSet() throws {
    let events = try makeCommands().setDue(
      taskID: TaskID("t1"), to: date("2026-10-23"), isHard: true, log: Self.log)

    #expect(events == [dueSet("t1", on: "2026-10-23", id: "id-1", lamport: 2)])
  }

  @Test("a target date is written as one")
  func aTargetDateIsWrittenAsOne() throws {
    let events = try makeCommands().setDue(
      taskID: TaskID("t1"), to: date("2026-10-23"), isHard: false, log: Self.log)

    #expect(events == [dueSet("t1", on: "2026-10-23", hard: false, id: "id-1", lamport: 2)])
  }

  @Test("setting the due date the task has writes nothing")
  func settingTheDueDateTheTaskHasWritesNothing() throws {
    let log = Self.log + [dueSet("t1", on: "2026-10-23", lamport: 2)]

    let events = try makeCommands().setDue(taskID: TaskID("t1"), to: date("2026-10-23"), isHard: true, log: log)

    #expect(events == [])
  }

  @Test("changing only whether it is hard is a change")
  func changingOnlyWhetherItIsHardIsAChange() throws {
    let log = Self.log + [dueSet("t1", on: "2026-10-23", lamport: 2)]

    let events = try makeCommands().setDue(taskID: TaskID("t1"), to: date("2026-10-23"), isHard: false, log: log)

    #expect(events == [dueSet("t1", on: "2026-10-23", hard: false, id: "id-1", lamport: 3)])
  }

  @Test("clearing it writes a TaskDueSet with no day, and nothing for a task with none")
  func clearingItWritesATaskDueSetWithNoDay() throws {
    let log = Self.log + [dueSet("t1", on: "2026-10-23", lamport: 2)]

    let events = try makeCommands().setDue(taskID: TaskID("t1"), to: nil, isHard: true, log: log)

    #expect(events == [dueSet("t1", on: nil, id: "id-1", lamport: 3)])
    #expect(try makeCommands().setDue(taskID: TaskID("t1"), to: nil, isHard: true, log: Self.log) == [])
  }

  @Test("a task that is not open is refused")
  func aTaskThatIsNotOpenIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().setDue(taskID: TaskID("t9"), to: date("2026-10-23"), isHard: true, log: Self.log)
    }
  }
}
