import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When a task is completed on a day")
struct CompletedOnTests {
  @Test("completing writes the day it was done on")
  func completingWritesTheDay() throws {
    let log = [captured("t1", "buy milk", lamport: 1)]

    let events = try Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
      .complete(taskID: TaskID("t1"), today: date("2026-10-19"), log: log)

    #expect(
      events.first?.payload == .taskCompleted(TaskCompleted(taskID: TaskID("t1"), completedOn: date("2026-10-19"))))
  }

  @Test("the completed task remembers the day")
  func completedTaskRemembersTheDay() {
    let log = [captured("t1", "buy milk", lamport: 1), completed("t1", on: "2026-10-19", lamport: 2)]

    #expect(LibraryState.replay(log).view(.default).completedTasks.map(\.completedOn) == [date("2026-10-19")])
  }

  @Test("what a project's completion takes along was completed on the same day")
  func projectTakesTheDayAlong() {
    let log = [
      projectCreated("p1", "Holiday", lamport: 1), captured("t1", "book flights", lamport: 2),
      moved("t1", to: "p1", lamport: 3), completed("p1", on: "2026-10-19", lamport: 4),
    ]
    let view = LibraryState.replay(log).view(.default)

    #expect(view.completedTasks.map(\.completedOn) == [date("2026-10-19")])
    #expect(view.completedProjects.map(\.completedOn) == [date("2026-10-19")])
  }

  @Test("a completion written before the day was kept has none")
  func olderCompletionsHaveNoDay() {
    let log = [captured("t1", "buy milk", lamport: 1), completed("t1", lamport: 2)]

    #expect(LibraryState.replay(log).view(.default).completedTasks.map(\.completedOn) == [nil])
  }

  @Test("reopening and completing again moves it to the new day")
  func completingAgainMovesTheDay() {
    let log = [
      captured("t1", "buy milk", lamport: 1), completed("t1", id: "c1", on: "2026-10-19", lamport: 2),
      reopened("t1", lamport: 3), completed("t1", id: "c2", on: "2026-10-22", lamport: 4),
    ]

    #expect(LibraryState.replay(log).view(.default).completedTasks.map(\.completedOn) == [date("2026-10-22")])
  }
}
