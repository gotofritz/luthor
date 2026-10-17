import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

private let monday = date("2026-10-19")

@Suite("When time is logged by command")
struct LogTimeCommandTests {
  static let log = [captured("t1", "write report", lamport: 1), captured("t2", "call bank", lamport: 2)]

  @Test("it writes one TaskTimeLogged")
  func itWritesOneTaskTimeLogged() throws {
    let events = try makeCommands().logTime(taskID: TaskID("t1"), on: monday, minutes: 45, log: Self.log)

    #expect(events == [timeLogged("t1", on: "2026-10-19", minutes: 45, id: "id-1", lamport: 3)])
  }

  @Test("a completed task can have time logged too")
  func aCompletedTaskCanHaveTimeLoggedToo() throws {
    let log = Self.log + [completed("t1", lamport: 3)]

    let events = try makeCommands().logTime(taskID: TaskID("t1"), on: monday, minutes: 45, log: log)

    #expect(events == [timeLogged("t1", on: "2026-10-19", minutes: 45, id: "id-1", lamport: 4)])
  }

  @Test("a task that does not exist, or was dropped, is refused")
  func aTaskThatDoesNotExistIsRefused() {
    let log = Self.log + [dropped("t2", lamport: 3)]

    #expect(throws: CommandError.unknownTask(TaskID("t9"))) {
      try makeCommands().logTime(taskID: TaskID("t9"), on: monday, minutes: 45, log: log)
    }
    #expect(throws: CommandError.unknownTask(TaskID("t2"))) {
      try makeCommands().logTime(taskID: TaskID("t2"), on: monday, minutes: 45, log: log)
    }
  }

  @Test("logging the minutes the day already has writes nothing")
  func loggingTheSameMinutesWritesNothing() throws {
    let log = Self.log + [timeLogged("t1", on: "2026-10-19", minutes: 45, lamport: 3)]

    #expect(try makeCommands().logTime(taskID: TaskID("t1"), on: monday, minutes: 45, log: log) == [])
  }

  @Test("clearing time that was never logged writes nothing")
  func clearingTimeThatWasNeverLoggedWritesNothing() throws {
    #expect(try makeCommands().logTime(taskID: TaskID("t1"), on: monday, minutes: nil, log: Self.log) == [])
  }

  @Test("zero or negative minutes clear the day's time")
  func zeroOrNegativeMinutesClearTheDaysTime() throws {
    let log = Self.log + [timeLogged("t1", on: "2026-10-19", minutes: 45, lamport: 3)]

    let zero = try makeCommands().logTime(taskID: TaskID("t1"), on: monday, minutes: 0, log: log)
    let negative = try makeCommands().logTime(taskID: TaskID("t1"), on: monday, minutes: -5, log: log)

    #expect(zero == [timeLogged("t1", on: "2026-10-19", minutes: nil, id: "id-1", lamport: 4)])
    #expect(negative == [timeLogged("t1", on: "2026-10-19", minutes: nil, id: "id-1", lamport: 4)])
  }
}

@Suite("When unplanned time is logged by command")
struct LogUnplannedTimeCommandTests {
  @Test("it writes one UnplannedTimeLogged")
  func itWritesOneUnplannedTimeLogged() throws {
    let events = try makeCommands().logUnplannedTime(25, for: .default, on: monday, log: [])

    #expect(events == [unplannedTimeLogged(25, on: "2026-10-19", id: "id-1", lamport: 1)])
  }

  @Test("logging the minutes the day already has writes nothing")
  func loggingTheSameMinutesWritesNothing() throws {
    let log = [unplannedTimeLogged(25, on: "2026-10-19", lamport: 1)]

    #expect(try makeCommands().logUnplannedTime(25, for: .default, on: monday, log: log) == [])
  }

  @Test("clearing the minutes of a day that has none writes nothing")
  func clearingTheMinutesOfADayThatHasNoneWritesNothing() throws {
    #expect(try makeCommands().logUnplannedTime(nil, for: .default, on: monday, log: []) == [])
  }

  @Test("a view that does not exist is refused")
  func aViewThatDoesNotExistIsRefused() {
    #expect(throws: CommandError.noView(ViewID("nowhere"))) {
      try makeCommands().logUnplannedTime(25, for: ViewID("nowhere"), on: monday, log: [])
    }
  }
}

@Suite("When a day is reviewed by command")
struct ReviewDayCommandTests {
  @Test("it writes one DayReviewed with the note")
  func itWritesOneDayReviewedWithTheNote() throws {
    let events = try makeCommands().reviewDay(of: .default, on: monday, note: "Too many calls", log: [])

    #expect(events == [dayReviewed(on: "2026-10-19", note: "Too many calls", id: "id-1", lamport: 1)])
  }

  @Test("a day can be reviewed with no note")
  func aDayCanBeReviewedWithNoNote() throws {
    let events = try makeCommands().reviewDay(of: .default, on: monday, note: nil, log: [])

    #expect(events == [dayReviewed(on: "2026-10-19", note: nil, id: "id-1", lamport: 1)])
  }

  @Test(
    "the note is one line: line breaks and runs of spaces become one space, and blank is no note",
    arguments: [
      ("  Too many   calls  ", "Too many calls"), ("Too many\ncalls", "Too many calls"),
      ("Too many\r\n\r\ncalls\t", "Too many calls"), ("   ", nil), ("\n", nil), ("", nil),
    ] as [(String, String?)])
  func theNoteIsOneLine(note: String, expected: String?) throws {
    let events = try makeCommands().reviewDay(of: .default, on: monday, note: note, log: [])

    #expect(events == [dayReviewed(on: "2026-10-19", note: expected, id: "id-1", lamport: 1)])
  }

  @Test("reviewing a day with the note it already has writes nothing")
  func reviewingADayWithTheSameNoteWritesNothing() throws {
    let log = [dayReviewed(on: "2026-10-19", note: "Too many calls", lamport: 1)]

    #expect(try makeCommands().reviewDay(of: .default, on: monday, note: "Too many calls", log: log) == [])
  }

  @Test("reviewing a day again with another note writes it")
  func reviewingADayAgainWithAnotherNoteWritesIt() throws {
    let log = [dayReviewed(on: "2026-10-19", note: "Too many calls", lamport: 1)]

    let events = try makeCommands().reviewDay(of: .default, on: monday, note: "Better", log: log)

    #expect(events == [dayReviewed(on: "2026-10-19", note: "Better", id: "id-1", lamport: 2)])
  }

  @Test("a view that does not exist is refused")
  func aViewThatDoesNotExistIsRefused() {
    #expect(throws: CommandError.noView(ViewID("nowhere"))) {
      try makeCommands().reviewDay(of: ViewID("nowhere"), on: monday, note: nil, log: [])
    }
  }
}
