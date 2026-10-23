import LuthorDomain
import LuthorTestSupport
import Testing

private let monday = date("2026-10-19")

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a planned task has sessions")
struct SessionTests {
  private let tasks = [
    captured("t1", "answer email", lamport: 1), estimated("t1", as: 60, lamport: 2),
    scheduled("t1", on: "2026-10-19", lamport: 3),
    captured("t2", "call bank", lamport: 4), estimated("t2", as: 30, lamport: 5),
    scheduled("t2", on: "2026-10-19", lamport: 6),
  ]

  private func plan(_ more: [EventEnvelope]) -> DayPlan {
    LibraryState.replay(tasks + more).plan(for: .default, on: monday, today: monday)
  }

  @Test("the plan lists its sessions, and the capacity still counts the whole estimate")
  func thePlanListsItsSessions() {
    let result = plan([sessionSet("s1", "t1", 540, 20, on: "2026-10-19", lamport: 7)])

    #expect(result.sessions.map(\.id) == [SessionID("s1")])
    #expect(result.sessions.map(\.minutes) == [20])
    #expect(result.capacity.plannedMinutes == 90)
  }

  @Test("the task's own block is what its sessions leave of it")
  func theOwnBlockShrinks() {
    let result = plan([sessionSet("s1", "t1", 540, 20, on: "2026-10-19", lamport: 7)]).layout()

    #expect(result.slots.first { $0.entry.task.id == TaskID("t1") }?.entry.minutes == 40)
    #expect(result.sessions.map(\.start) == [540])
    #expect(result.sessions.map(\.end) == [560])
  }

  @Test("sessions that take the whole estimate leave no block of the task's own")
  func noOwnBlockLeft() {
    let result = plan([sessionSet("s1", "t1", 540, 70, on: "2026-10-19", lamport: 7)]).layout()

    #expect(result.slots.map(\.entry.task.id) == [TaskID("t2")])
  }

  @Test("a session that would overlap one of the same day is pushed to the end of it")
  func sessionsDoNotOverlap() {
    let result = plan([
      sessionSet("s1", "t1", 540, 30, on: "2026-10-19", lamport: 7),
      sessionSet("s2", "t2", 550, 20, on: "2026-10-19", lamport: 8),
    ]).layout()

    #expect(result.sessions.map(\.start) == [540, 570])
  }

  @Test("a session dropped on another wins its place and the other moves")
  func aMovedSessionWins() {
    let result = plan([
      sessionSet("s1", "t1", 540, 30, on: "2026-10-19", lamport: 7),
      sessionSet("s2", "t2", 600, 20, on: "2026-10-19", lamport: 8),
    ]).layout(to: 550, movingSession: SessionID("s2"))

    #expect(result.sessions.map(\.session.id) == [SessionID("s2"), SessionID("s1")])
    #expect(result.sessions.map(\.start) == [550, 570])
  }

  @Test("a session of a task that is not planned for its day is ignored")
  func anUnplannedTaskHasNoSession() {
    let result = plan([
      sessionSet("s1", "t1", 540, 20, on: "2026-10-19", lamport: 7),
      scheduled("t1", on: "2026-10-20", lamport: 8),
    ])

    #expect(result.sessions.isEmpty)
  }

  @Test("removing a session gives its minutes back")
  func removingGivesTheMinutesBack() {
    let result = plan([
      sessionSet("s1", "t1", 540, 20, on: "2026-10-19", lamport: 7), sessionRemoved("s1", lamport: 8),
    ])

    #expect(result.sessions.isEmpty)
  }

  @Test("the command sets a session and refuses a stretch that does not fit")
  func theCommandSetsASession() throws {
    let events = try makeCommands().setSession(of: TaskID("t1"), on: monday, start: 540, minutes: 30, log: tasks)

    #expect(LibraryState.replay(tasks + events).sessions(on: monday).map(\.minutes) == [30])
    #expect(throws: CommandError.invalidSession) {
      try makeCommands().setSession(of: TaskID("t1"), on: monday, start: 540, minutes: 0, log: tasks)
    }
    #expect(throws: CommandError.noSession(SessionID("zz"))) {
      try makeCommands().removeSession(SessionID("zz"), log: tasks)
    }
  }
}

@Suite("When a task planned for a day is done")
struct DoneTaskTests {
  private let events = [
    captured("t1", "write report", lamport: 1), estimated("t1", as: 60, lamport: 2),
    scheduled("t1", on: "2026-10-19", lamport: 3), startSet("t1", 600, on: "2026-10-19", lamport: 4),
    captured("t2", "call bank", lamport: 5), estimated("t2", as: 30, lamport: 6),
    scheduled("t2", on: "2026-10-19", lamport: 7),
  ]

  private func plan(_ more: [EventEnvelope]) -> DayPlan {
    LibraryState.replay(events + more).plan(for: .default, on: monday, today: monday)
  }

  @Test("it stays on the day where it stood, and is not among the open entries")
  func itStaysWhereItStood() {
    let result = plan([completed("t1", lamport: 8)])

    #expect(result.entries.map(\.task.id) == [TaskID("t2")])
    #expect(result.done.map(\.task.id) == [TaskID("t1")])
    #expect(result.layout().done.map(\.start) == [600])
    #expect(result.layout().done.map(\.end) == [660])
  }

  @Test("a task dropped on it is pushed to the end of it")
  func aDroppedTaskIsPushedPast() {
    let result = plan([completed("t1", lamport: 8)]).layout(moving: TaskID("t2"), to: 620)

    #expect(result.done.map(\.start) == [600])
    #expect(result.slots.map(\.start) == [660])
  }

  @Test("it does not count in the capacity")
  func itDoesNotCount() {
    #expect(plan([completed("t1", lamport: 8)]).capacity.plannedMinutes == 30)
  }

  @Test("reopened, it is planned for its day again, at its start")
  func reopenedItIsPlannedAgain() {
    let result = plan([completed("t1", lamport: 8), reopened("t1", lamport: 9)])

    #expect(result.done.isEmpty)
    #expect(result.entries.map(\.task.id).contains(TaskID("t1")))
    #expect(result.entries.first { $0.task.id == TaskID("t1") }?.start == 600)
  }
}
