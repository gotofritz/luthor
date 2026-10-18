import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

private let monday = date("2026-10-19")

/// A task and a project with a task in it, one completed; the lamport counter is 4.
private let log: [EventEnvelope] = [
  captured("t1", "buy milk", lamport: 1),
  projectCreated("p1", "Holiday", lamport: 2),
  captured("t2", "pack", lamport: 3), moved("t2", to: "p1", lamport: 4),
  captured("t3", "book flights", lamport: 4), completed("t3", lamport: 4),
]

@Suite("When a task is duplicated by command")
struct DuplicateCommandTests {
  @Test("it writes one TaskDuplicated naming the new task and the day it is made")
  func itWritesOneTaskDuplicated() throws {
    let events = try makeCommands().duplicate(taskID: TaskID("t1"), today: monday, log: log)

    #expect(events == [duplicated("t1", as: "id-2", on: "2026-10-19", id: "id-1", lamport: 5)])
  }

  @Test("the day it is made is optional")
  func theDayIsOptional() throws {
    let events = try makeCommands().duplicate(taskID: TaskID("t2"), log: log)

    #expect(events == [duplicated("t2", as: "id-2", id: "id-1", lamport: 5)])
  }

  @Test("a task that is not open is refused", arguments: ["t3", "ghost"])
  func aTaskThatIsNotOpenIsRefused(task: String) {
    #expect(throws: CommandError.noOpenTask(task)) {
      try makeCommands().duplicate(taskID: TaskID(task), log: log)
    }
  }
}

@Suite("When a task is deleted by command")
struct DeleteTaskCommandTests {
  @Test("an open task and a completed one each write one TaskDeleted", arguments: ["t1", "t2", "t3"])
  func itWritesOneTaskDeleted(task: String) throws {
    let events = try makeCommands().delete(taskID: TaskID(task), log: log)

    #expect(events == [taskDeleted(task, id: "id-1", lamport: 5)])
  }

  @Test("a task that does not exist is refused")
  func aTaskThatDoesNotExistIsRefused() {
    #expect(throws: CommandError.unknownTask(TaskID("ghost"))) {
      try makeCommands().delete(taskID: TaskID("ghost"), log: log)
    }
  }

  @Test("a task that was deleted already is refused")
  func aDeletedTaskIsRefused() {
    #expect(throws: CommandError.unknownTask(TaskID("t1"))) {
      try makeCommands().delete(taskID: TaskID("t1"), log: log + [taskDeleted("t1", lamport: 5)])
    }
  }
}

@Suite("When a project is deleted by command")
struct DeleteProjectCommandTests {
  @Test("an active project and a completed one each write one ProjectDeleted")
  func itWritesOneProjectDeleted() throws {
    let active = try makeCommands().delete(projectID: ProjectID("p1"), log: log)
    let done = try makeCommands().delete(
      projectID: ProjectID("p1"), log: log + [projectCompleted("p1", lamport: 5)])

    #expect(active == [projectDeleted("p1", id: "id-1", lamport: 5)])
    #expect(done == [projectDeleted("p1", id: "id-1", lamport: 6)])
  }

  @Test("a project that does not exist is refused")
  func aProjectThatDoesNotExistIsRefused() {
    #expect(throws: CommandError.unknownProject(ProjectID("ghost"))) {
      try makeCommands().delete(projectID: ProjectID("ghost"), log: log)
    }
  }
}

@Suite("When a task is made into a project by command")
struct PromoteCommandTests {
  @Test("it writes one TaskPromotedToProject naming the new project")
  func itWritesOneTaskPromotedToProject() throws {
    let events = try makeCommands().promote(taskID: TaskID("t1"), log: log)

    #expect(events == [promoted("t1", to: "id-2", id: "id-1", lamport: 5)])
  }

  @Test("a task that is not open is refused", arguments: ["t3", "ghost"])
  func aTaskThatIsNotOpenIsRefused(task: String) {
    #expect(throws: CommandError.noOpenTask(task)) {
      try makeCommands().promote(taskID: TaskID(task), log: log)
    }
  }
}
