import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a task is reopened by command")
struct ReopenTaskCommandTests {
  static let log = [captured("t1", "buy milk", lamport: 1), completed("t1", lamport: 2)]

  @Test("it writes one TaskReopened")
  func reopenWritesTaskReopened() throws {
    let events = try makeCommands().reopen(taskID: TaskID("t1"), log: Self.log)

    #expect(events == [reopened("t1", id: "id-1", lamport: 3)])
  }

  @Test("a task that is open is refused")
  func reopeningAnOpenTaskIsRefused() {
    #expect(throws: CommandError.noCompletedTask(TaskID("t1"))) {
      try makeCommands().reopen(taskID: TaskID("t1"), log: [captured("t1", "buy milk")])
    }
  }

  @Test("a task completed along with its project is refused")
  func reopeningACascadedTaskIsRefused() {
    let log = [
      projectCreated("p1", "Holiday", lamport: 1), captured("t1", "flights", lamport: 2),
      moved("t1", to: "p1", lamport: 3), projectCompleted("p1", lamport: 4),
    ]

    #expect(throws: CommandError.noCompletedTask(TaskID("t1"))) {
      try makeCommands().reopen(taskID: TaskID("t1"), log: log)
    }
  }
}

@Suite("When a project is reopened by command")
struct ReopenProjectCommandTests {
  static let log = [projectCreated("p1", "Holiday", lamport: 1), projectCompleted("p1", lamport: 2)]

  @Test("it writes one TaskReopened")
  func reopenWritesProjectReopened() throws {
    let events = try makeCommands().reopenProject(TaskID("p1"), log: Self.log)

    #expect(events == [projectReopened("p1", id: "id-1", lamport: 3)])
  }

  @Test("a project that is active is refused")
  func reopeningAnActiveProjectIsRefused() {
    #expect(throws: CommandError.noCompletedProject(TaskID("p1"))) {
      try makeCommands().reopenProject(TaskID("p1"), log: [projectCreated("p1", "Holiday")])
    }
  }

  @Test("a project completed along with its parent is refused")
  func reopeningACascadedProjectIsRefused() {
    let log = [
      projectCreated("p1", "Holiday", lamport: 1), projectCreated("p2", "Packing", under: "p1", lamport: 2),
      projectCompleted("p1", lamport: 3),
    ]

    #expect(throws: CommandError.noCompletedProject(TaskID("p2"))) {
      try makeCommands().reopenProject(TaskID("p2"), log: log)
    }
  }
}
