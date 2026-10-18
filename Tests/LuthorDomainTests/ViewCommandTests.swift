import LuthorDomain
import LuthorTestSupport
import Testing

private func commands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a view is created or renamed")
struct ViewCommandTests {
  @Test("creating one writes ViewCreated with the trimmed name")
  func createViewWritesViewCreated() throws {
    let events = try commands().createView(name: " Work ", log: [])

    #expect(events == [viewCreated("id-2", "Work", id: "id-1", lamport: 1)])
  }

  @Test("a blank name is refused", arguments: ["", "  "])
  func blankViewNameIsRefused(name: String) {
    #expect(throws: CommandError.blankTitle) { try commands().createView(name: name, log: []) }
  }

  @Test("a name another view has, in any case, is refused")
  func duplicateViewNameIsRefused() {
    #expect(throws: CommandError.duplicateViewName("default")) {
      try commands().createView(name: "default", log: [])
    }
  }

  @Test("renaming one writes ViewRenamed")
  func renameViewWritesViewRenamed() throws {
    let events = try commands().renameView(.default, to: "Private", log: [captured("t1", "a", lamport: 4)])

    #expect(events == [viewRenamed("default", to: "Private", id: "id-1", lamport: 5)])
  }

  @Test("renaming a view to its own name in another case is allowed")
  func renamingToTheSameNameIsAllowed() throws {
    #expect(try commands().renameView(.default, to: "DEFAULT", log: []).count == 1)
  }

  @Test("renaming an unknown view, or to another view's name, is refused")
  func invalidRenamesAreRefused() {
    let log = [viewCreated("v1", "Work", lamport: 1)]

    #expect(throws: CommandError.noView(ViewID("v9"))) { try commands().renameView(ViewID("v9"), to: "X", log: log) }
    #expect(throws: CommandError.duplicateViewName("work")) {
      try commands().renameView(.default, to: "work", log: log)
    }
    #expect(throws: CommandError.blankTitle) { try commands().renameView(.default, to: " ", log: log) }
  }
}

@Suite("When a task is captured or a project created in a view")
struct ViewCaptureCommandTests {
  static let log = [viewCreated("work", "Work", lamport: 1), projectCreated("wp", "Q4 plan", view: "work", lamport: 2)]

  @Test("the task is captured into that view")
  func captureWritesTheView() throws {
    let events = try commands().capture(title: "write the report", in: ViewID("work"), log: Self.log)

    #expect(events == [captured("id-2", "write the report", id: "id-1", view: "work", lamport: 3)])
  }

  @Test("a task captured into a project takes the project's view")
  func captureIntoAProjectTakesItsView() throws {
    let events = try commands().capture(title: "draft", into: TaskID("wp"), log: Self.log)

    #expect(events.first == captured("id-2", "draft", id: "id-1", view: "work", lamport: 3))
  }

  @Test("the project is created in that view")
  func createProjectWritesTheView() throws {
    let events = try commands().createProject(title: "Offsite", kind: .parallel, in: ViewID("work"), log: Self.log)

    #expect(events == [projectCreated("id-2", "Offsite", id: "id-1", view: "work", lamport: 3)])
  }

  @Test("an unknown view is refused")
  func unknownViewIsRefused() {
    #expect(throws: CommandError.noView(ViewID("v9"))) {
      try commands().capture(title: "a", in: ViewID("v9"), log: Self.log)
    }
    #expect(throws: CommandError.noView(ViewID("v9"))) {
      try commands().createProject(title: "a", kind: .parallel, in: ViewID("v9"), log: Self.log)
    }
  }
}

@Suite("Given a task in the default view and a project in Work")
struct CrossViewCommandTests {
  static let log = [
    viewCreated("work", "Work", lamport: 1),
    projectCreated("wp", "Q4 plan", view: "work", lamport: 2),
    captured("t1", "write the report", lamport: 3),
    captured("w1", "plan the offsite", view: "work", lamport: 4),
  ]

  @Test("filing the task into the project is refused")
  func filingAcrossViewsIsRefused() {
    #expect(throws: CommandError.otherView(TaskID("t1"), TaskID("wp"))) {
      try commands().move(taskID: TaskID("t1"), to: TaskID("wp"), log: Self.log)
    }
  }

  @Test("moving the task to Work writes TaskMovedToView")
  func moveTaskToViewWritesTaskMovedToView() throws {
    let events = try commands().move(taskID: TaskID("t1"), toView: ViewID("work"), log: Self.log)

    #expect(events == [movedToView("t1", toView: "work", id: "id-1", lamport: 5)])
  }

  @Test("moving the project to the default view writes TaskMovedToView")
  func moveProjectToViewWritesProjectMovedToView() throws {
    let events = try commands().move(projectID: TaskID("wp"), toView: .default, log: Self.log)

    #expect(events == [projectMovedToView("wp", toView: "default", id: "id-1", lamport: 5)])
  }

  @Test("moving either into the view it is in writes nothing")
  func movingWithinAViewWritesNothing() throws {
    #expect(try commands().move(taskID: TaskID("t1"), toView: .default, log: Self.log).isEmpty)
    #expect(try commands().move(projectID: TaskID("wp"), toView: ViewID("work"), log: Self.log).isEmpty)
  }

  @Test("moving to an unknown view, or something not open, is refused")
  func invalidMovesAreRefused() {
    let commands = commands()

    #expect(throws: CommandError.noView(ViewID("v9"))) {
      try commands.move(taskID: TaskID("t1"), toView: ViewID("v9"), log: Self.log)
    }
    #expect(throws: CommandError.noView(ViewID("v9"))) {
      try commands.move(projectID: TaskID("wp"), toView: ViewID("v9"), log: Self.log)
    }
    #expect(throws: CommandError.noOpenTask("t9")) {
      try commands.move(taskID: TaskID("t9"), toView: .default, log: Self.log)
    }
    #expect(throws: CommandError.noActiveProject(TaskID("p9"))) {
      try commands.move(projectID: TaskID("p9"), toView: .default, log: Self.log)
    }
  }
}
