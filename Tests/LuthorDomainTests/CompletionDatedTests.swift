import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

private let today = date("2026-10-30")

@Suite("When a completion is dated afterwards")
struct CompletionDatedReplayTests {
  @Test("a completed task takes the day")
  func completedTaskTakesTheDay() {
    let log = [
      captured("t1", "buy milk", lamport: 1), completed("t1", lamport: 2), completionDated("t1", on: "2026-10-20"),
    ]

    #expect(LibraryState.replay(log).view(.default).completedTasks.map(\.completedOn) == [date("2026-10-20")])
  }

  @Test("an open task is left alone")
  func openTaskIsLeftAlone() {
    let log = [captured("t1", "buy milk", lamport: 1), completionDated("t1", on: "2026-10-20", lamport: 2)]
    let reopenedLog = log + [completed("t1", lamport: 3), reopened("t1", lamport: 4)]

    #expect(LibraryState.replay(log).view(.default).openTasks.map(\.id) == [TaskID("t1")])
    #expect(LibraryState.replay(reopenedLog).view(.default).completedTasks.isEmpty)
  }
}

@Suite("When the old completions are dated")
struct DateOldCompletionsTests {
  @Test("a completion with no day takes the due date")
  func takesTheDueDate() throws {
    let log = [
      captured("t1", "pay tax", lamport: 1), dueSet("t1", on: "2026-10-12", lamport: 2), completed("t1", lamport: 3),
    ]

    let events = try makeCommands().dateOldCompletions(today: today, log: log)

    #expect(
      events.map(\.payload) == [
        .completionDated(CompletionDated(taskID: TaskID("t1"), completedOn: date("2026-10-12")))
      ])
  }

  @Test("without a due date it takes the day it was planned for")
  func takesThePlannedDay() throws {
    let log = [
      captured("t1", "pay tax", lamport: 1), scheduled("t1", on: "2026-10-14", lamport: 2), completed("t1", lamport: 3),
    ]

    let events = try makeCommands().dateOldCompletions(today: today, log: log)

    #expect(
      events.map(\.payload) == [
        .completionDated(CompletionDated(taskID: TaskID("t1"), completedOn: date("2026-10-14")))
      ])
  }

  @Test("with neither it takes three days ago")
  func takesThreeDaysAgo() throws {
    let log = [captured("t1", "pay tax", lamport: 1), completed("t1", lamport: 2)]

    let events = try makeCommands().dateOldCompletions(today: today, log: log)

    #expect(
      events.map(\.payload) == [
        .completionDated(CompletionDated(taskID: TaskID("t1"), completedOn: date("2026-10-27")))
      ])
  }

  @Test("a completion that has a day is left alone, and a second run has nothing to do")
  func leavesDatedOnesAlone() throws {
    let log = [
      captured("t1", "a", lamport: 1), completed("t1", id: "c1", on: "2026-10-29", lamport: 2),
      captured("t2", "b", lamport: 3), completed("t2", id: "c2", lamport: 4),
    ]
    let commands = makeCommands()

    let first = try commands.dateOldCompletions(today: today, log: log)
    let second = try commands.dateOldCompletions(today: today, log: log + first)

    #expect(first.count == 1)
    #expect(second.isEmpty)
  }

  @Test("a dropped item has no completion to date")
  func skipsDropped() throws {
    let log = [captured("t1", "a", lamport: 1), dropped("t1", lamport: 2)]

    #expect(try makeCommands().dateOldCompletions(today: today, log: log).isEmpty)
  }
}
