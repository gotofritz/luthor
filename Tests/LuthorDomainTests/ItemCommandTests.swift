import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

/// A project "Trip" holding one task, and a plain task "Lone".
private let log = [
  projectCreated("p1", "Trip", lamport: 1),
  captured("t1", "book flights", under: "p1", lamport: 2),
  captured("t2", "Lone", lamport: 3),
]

@Suite("When a project is given the fields a task has")
struct ProjectFieldCommandTests {
  static let trip = TaskID("p1")

  @Test("a priority is set on it and shown on the project")
  func priority() throws {
    let events = try makeCommands().prioritize(taskID: Self.trip, as: .important, log: log)

    let project = try #require(LibraryState.replay(log + events).projects.first)
    #expect(project.priority == .important)
  }

  @Test("an estimate is set on it and shown on the project")
  func estimate() throws {
    let events = try makeCommands().estimate(taskID: Self.trip, as: 90, log: log)

    let project = try #require(LibraryState.replay(log + events).projects.first)
    #expect(project.estimate == 90)
  }

  @Test("a due date is set on it")
  func dueDate() throws {
    let events = try makeCommands().setDue(taskID: Self.trip, to: date("2027-04-01"), isHard: true, log: log)

    let state = LibraryState.replay(log + events)
    #expect(state.dueDate(of: Self.trip) == DueDate(date: date("2027-04-01"), isHard: true))
  }

  @Test("tags are set on it")
  func tags() throws {
    let events = try makeCommands().setTags(taskID: Self.trip, to: ["travel"], log: log)

    let state = LibraryState.replay(log + events)
    #expect(state.tags(of: Self.trip).map(\.name) == ["travel"])
  }

  @Test("a repeat is set on it, with a due date to count from")
  func repeatRule() throws {
    let rule = RepeatRule(every: 1, unit: .year)

    let events = try makeCommands().setRepeat(taskID: Self.trip, to: rule, dueIfNone: date("2027-04-01"), log: log)

    let state = LibraryState.replay(log + events)
    #expect(state.repeatRule(of: Self.trip) == rule)
  }

  @Test("it is renamed and given notes by the task commands")
  func renameAndNotes() throws {
    let renamed = try makeCommands().rename(taskID: Self.trip, to: "Spring trip", log: log)
    let noted = try makeCommands().setNotes(taskID: Self.trip, to: "Lisbon", log: log + renamed)

    let project = try #require(LibraryState.replay(log + renamed + noted).projects.first)
    #expect(project.title == "Spring trip")
    #expect(project.notes == "Lisbon")
  }
}

@Suite("When an item is made a container")
struct ContainerCommandTests {
  @Test("a task gets a kind, and so becomes a project that keeps its fields")
  func kindOnATask() throws {
    let prioritized = try makeCommands().prioritize(taskID: TaskID("t2"), as: .critical, log: log)

    let events = try makeCommands().setKind(of: TaskID("t2"), to: .sequential, log: log + prioritized)

    let state = LibraryState.replay(log + prioritized + events)
    let project = try #require(state.projects.first { $0.id == TaskID("t2") })
    #expect(project.kind == .sequential)
    #expect(project.priority == .critical)
  }

  @Test("a task can be filed under another task, which then holds it")
  func fileUnderATask() throws {
    let events = try makeCommands().move(taskID: TaskID("t1"), to: TaskID("t2"), log: log)

    let state = LibraryState.replay(log + events)
    let holder = try #require(state.projects.first { $0.id == TaskID("t2") })
    #expect(holder.tasks.map(\.id) == [TaskID("t1")])
  }

  @Test("a project can be completed by the task command, taking its tasks along")
  func completeAProject() throws {
    let events = try makeCommands().complete(taskID: TaskID("p1"), log: log)

    let state = LibraryState.replay(log + events)
    #expect(state.completedProjects.map(\.item.id) == [TaskID("p1")])
    #expect(state.completedTasks.map(\.item.id) == [TaskID("t1")])
  }

  @Test("a completed project is reopened by the task command too")
  func reopenAProject() throws {
    let done = try makeCommands().complete(taskID: TaskID("p1"), log: log)

    let events = try makeCommands().reopen(taskID: TaskID("p1"), log: log + done)

    let state = LibraryState.replay(log + done + events)
    #expect(state.projects.map(\.id) == [TaskID("p1")])
  }

  @Test("an item that does not exist is still refused")
  func unknownItem() {
    #expect(throws: CommandError.noOpenTask("ghost")) {
      try makeCommands().prioritize(taskID: TaskID("ghost"), as: .critical, log: log)
    }
  }
}
