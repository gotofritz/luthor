import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a project is created under another by command")
struct CreateSubprojectCommandTests {
  @Test("it writes one TaskCaptured with the parent, in the parent's view")
  func createSubprojectWritesTaskCapturedWithParent() throws {
    let log = [viewCreated("v1", "Work", lamport: 1), projectCreated("p1", "Q4 plan", view: "v1", lamport: 2)]

    let events = try makeCommands().createProject(
      title: " Hiring ", kind: .sequential, under: TaskID("p1"), log: log)

    #expect(
      events == [projectCreated("id-2", "Hiring", kind: .sequential, under: "p1", id: "id-1", view: "v1", lamport: 3)])
  }

  @Test("a parent that is not active is refused")
  func createUnderAnUnknownProjectIsRefused() {
    #expect(throws: CommandError.noActiveProject(TaskID("p9"))) {
      try makeCommands().createProject(title: "Kitchen", kind: .parallel, under: TaskID("p9"), log: [])
    }
  }

  @Test("a blank title is refused")
  func blankSubprojectTitleIsRefused() {
    #expect(throws: CommandError.blankTitle) {
      try makeCommands().createProject(
        title: " ", kind: .parallel, under: TaskID("p1"), log: [projectCreated("p1", "Home")])
    }
  }
}

@Suite("When a project is nested by command")
struct NestProjectCommandTests {
  static let log = [
    projectCreated("p1", "Home", lamport: 1),
    projectCreated("p2", "Kitchen", lamport: 2),
    projectCreated("p3", "Tap", under: "p2", lamport: 3),
  ]

  @Test("it writes one TaskMoved")
  func nestWritesProjectMovedToProject() throws {
    let events = try makeCommands().move(projectID: TaskID("p2"), under: TaskID("p1"), log: Self.log)

    #expect(events == [nested("p2", under: "p1", id: "id-1", lamport: 4)])
  }

  @Test("moving it to the top writes one TaskMoved without a parent")
  func unnestWritesProjectMovedToProjectWithoutParent() throws {
    let events = try makeCommands().move(projectID: TaskID("p3"), under: nil, log: Self.log)

    #expect(events == [nested("p3", under: nil, id: "id-1", lamport: 4)])
  }

  @Test(
    "moving it where it already is writes nothing",
    arguments: [("p3", Optional("p2")), ("p1", nil)])
  func nestingWhereItIsWritesNothing(project: String, parent: String?) throws {
    let events = try makeCommands().move(
      projectID: TaskID(project), under: parent.map(TaskID.init), log: Self.log)

    #expect(events == [])
  }

  @Test("nesting it under itself or one of its sub-projects is refused", arguments: ["p2", "p3"])
  func nestingUnderItselfIsRefused(parent: String) {
    #expect(throws: CommandError.nestedUnderItself(TaskID("p2"))) {
      try makeCommands().move(projectID: TaskID("p2"), under: TaskID(parent), log: Self.log)
    }
  }

  @Test("nesting it under a project of another view is refused")
  func nestingAcrossViewsIsRefused() {
    let log =
      Self.log + [
        viewCreated("v1", "Work", lamport: 4),
        projectCreated("p4", "Q4 plan", view: "v1", lamport: 5),
      ]

    #expect(throws: CommandError.projectInOtherView(TaskID("p2"), parent: TaskID("p4"))) {
      try makeCommands().move(projectID: TaskID("p2"), under: TaskID("p4"), log: log)
    }
  }

  @Test("a project or a parent that is not active is refused", arguments: [("p9", "p1"), ("p2", "p9")])
  func nestingInactiveProjectsIsRefused(project: String, parent: String) {
    #expect(throws: CommandError.noActiveProject(TaskID("p9"))) {
      try makeCommands().move(projectID: TaskID(project), under: TaskID(parent), log: Self.log)
    }
  }
}
