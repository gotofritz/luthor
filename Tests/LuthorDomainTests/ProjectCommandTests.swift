import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a project is created by command")
struct CreateProjectCommandTests {
  @Test("it writes one TaskCaptured with the kind after the highest Lamport in the log")
  func createProjectWritesTaskCaptured() throws {
    let events = try makeCommands().createProject(
      title: "  Move house ", kind: .sequential, in: .default, log: [captured("t1", "a", lamport: 4)])

    #expect(
      events == [
        projectCreated("id-2", "Move house", kind: .sequential, id: "id-1", lamport: 5)
      ])
  }

  @Test("a blank title is refused", arguments: ["", "  ", "\n"])
  func blankProjectTitleIsRefused(title: String) {
    #expect(throws: CommandError.blankTitle) {
      try makeCommands().createProject(title: title, kind: .parallel, in: .default, log: [])
    }
  }
}

@Suite("When a task is filed by command")
struct MoveCommandTests {
  static let log = [
    captured("t1", "book flights", lamport: 1),
    projectCreated("p1", "Holiday", lamport: 2),
  ]

  @Test("it writes one TaskMoved")
  func moveWritesTaskMoved() throws {
    let events = try makeCommands().move(taskID: TaskID("t1"), to: TaskID("p1"), log: Self.log)

    #expect(events == [moved("t1", to: "p1", id: "id-1", lamport: 3)])
  }

  @Test("filing it where it already is writes nothing")
  func movingIntoTheSameProjectWritesNothing() throws {
    let log = Self.log + [moved("t1", to: "p1", lamport: 3)]

    #expect(try makeCommands().move(taskID: TaskID("t1"), to: TaskID("p1"), log: log) == [])
  }

  @Test("a task that is not open is refused")
  func movingAClosedTaskIsRefused() {
    let log = Self.log + [completed("t1", lamport: 3)]

    #expect(throws: CommandError.noOpenTask("t1")) {
      try makeCommands().move(taskID: TaskID("t1"), to: TaskID("p1"), log: log)
    }
  }

  @Test("a project that is not active is refused")
  func movingIntoACompletedProjectIsRefused() {
    let log = Self.log + [projectCompleted("p1", lamport: 3)]

    #expect(throws: CommandError.noActiveProject(TaskID("p1"))) {
      try makeCommands().move(taskID: TaskID("t1"), to: TaskID("p1"), log: log)
    }
  }
}

@Suite("When a task is captured into a project")
struct CaptureIntoProjectCommandTests {
  @Test("it writes one TaskCaptured filed in the project")
  func captureIntoProjectWritesOneCapture() throws {
    let log = [projectCreated("p1", "Holiday", lamport: 1)]

    let events = try makeCommands().capture(title: "book flights", into: TaskID("p1"), log: log)

    #expect(events == [captured("id-2", "book flights", id: "id-1", under: "p1", lamport: 2)])
  }

  @Test("a project that is not active is refused")
  func captureIntoAnUnknownProjectIsRefused() {
    #expect(throws: CommandError.noActiveProject(TaskID("p9"))) {
      try makeCommands().capture(title: "book flights", into: TaskID("p9"), log: [])
    }
  }
}

@Suite("When a project is completed by command")
struct CompleteProjectCommandTests {
  @Test("it writes one TaskCompleted")
  func completeProjectWritesTaskCompleted() throws {
    let events = try makeCommands().completeProject(TaskID("p1"), log: [projectCreated("p1", "Holiday")])

    #expect(events == [projectCompleted("p1", id: "id-1", lamport: 2)])
  }

  @Test("a project that is not active is refused")
  func completingAnUnknownProjectIsRefused() {
    #expect(throws: CommandError.noActiveProject(TaskID("p1"))) {
      try makeCommands().completeProject(TaskID("p1"), log: [])
    }
  }
}
