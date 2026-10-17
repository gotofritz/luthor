import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given two top-level projects, when one is dragged onto the other")
struct NestingFlowTests {
  @Test("it leaves the first column and shows in the other's column, after a relaunch too")
  func draggedProjectNestsUnderTheTarget() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let home = try library.createProject("Home", kind: .parallel)
    let kitchen = try library.createProject("Kitchen", kind: .parallel)

    library.drop([LibraryViewModel.dragPayload(for: kitchen)], on: home)

    #expect(library.columns.first?.entries.map(\.id) == ["project-\(home.rawValue)"])
    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.open(.project(home))
    #expect(relaunched.columns.last?.entries.map(\.id) == ["project-\(kitchen.rawValue)"])
  }

  @Test("dragging it out to the top makes it top-level again")
  func draggedOutProjectIsTopLevel() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let home = try library.createProject("Home", kind: .parallel)
    let kitchen = try library.createProject("Kitchen", kind: .parallel)
    library.drop([LibraryViewModel.dragPayload(for: kitchen)], on: home)

    library.drop([LibraryViewModel.dragPayload(for: kitchen)], on: nil)

    #expect(library.columns.first?.entries.map(\.id) == ["project-\(home.rawValue)", "project-\(kitchen.rawValue)"])
  }

  @Test("a project dragged onto one of its own sub-projects stays where it is")
  func projectCannotNestUnderItsOwnSubproject() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let home = try library.createProject("Home", kind: .parallel)
    let kitchen = try library.createProject("Kitchen", kind: .parallel)
    library.drop([LibraryViewModel.dragPayload(for: kitchen)], on: home)

    library.drop([LibraryViewModel.dragPayload(for: home)], on: kitchen)

    #expect(library.columns.first?.entries.map(\.id) == ["project-\(home.rawValue)"])
    #expect(library.errorMessage == nil)
  }
}

@MainActor
@Suite("Given a project shown in the columns, when a project is created")
struct SubprojectCreationFlowTests {
  @Test("it is created inside, and opening it adds a column for it")
  func projectCreatedInAShownProjectIsNested() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let home = try library.createProject("Home", kind: .parallel)
    library.open(.project(home))

    let kitchen = try library.createProject("Kitchen", kind: .parallel)
    library.open(.project(kitchen))

    #expect(library.path == [home, kitchen])
    #expect(library.columns.map(\.parentID) == [nil, home, kitchen])
    let relaunched = launchApp(on: dir.file("events.jsonl"))
    #expect(relaunched.columns.first?.entries.map(\.id) == ["project-\(home.rawValue)"])
  }
}

@MainActor
@Suite("Given a sequential project whose first child is a sub-project")
struct NestedNextActionFlowTests {
  @Test("only the sub-project's next actions are next; the parent's later task waits")
  func onlyTheSubprojectsNextActionsAreNext() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let home = try library.createProject("Home", kind: .sequential)
    library.open(.project(home))
    let kitchen = try library.createProject("Kitchen", kind: .parallel)
    library.capture("clear the attic")
    library.open(.project(kitchen))
    library.capture("replace the tap")
    library.capture("paint the wall")

    let tap = try library.task("replace the tap")
    let wall = try library.task("paint the wall")
    try #require(library.columns.count == 3)
    #expect(library.columns[1].entries.first?.id == "project-\(kitchen.rawValue)")
    #expect(library.columns[1].entries.count == 2)
    #expect(library.nextActions == [tap, wall])
  }

  @Test("once the sub-project is completed, the next child is next")
  func completingTheSubprojectPromotesTheNextChild() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let home = try library.createProject("Home", kind: .sequential)
    library.open(.project(home))
    let kitchen = try library.createProject("Kitchen", kind: .parallel)
    library.capture("clear the attic")
    library.open(.project(kitchen))
    library.capture("replace the tap")

    library.completeProject(kitchen)
    library.open(.project(home))

    let attic = try library.task("clear the attic")
    #expect(library.tasks.map(\.title) == ["clear the attic"])
    #expect(library.nextActions == [attic])
  }
}

@MainActor
@Suite("Given a project with a sub-project, when the project is completed")
struct NestedCompletionFlowTests {
  @Test("the sub-project and every open task in both are gone")
  func completingAProjectCompletesItsSubtree() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let home = try library.createProject("Home", kind: .parallel)
    let kitchen = try library.createProject("Kitchen", kind: .parallel)
    library.drop([LibraryViewModel.dragPayload(for: kitchen)], on: home)
    library.open(.project(kitchen))
    library.capture("replace the tap")
    library.open(.project(home))
    library.capture("clear the attic")

    library.completeProject(home)

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    #expect(relaunched.projects.isEmpty)
    #expect(relaunched.tasks.isEmpty)
  }
}

@MainActor
@Suite("Given a project with a sub-project, when the project is moved to another view")
struct NestedViewMoveFlowTests {
  @Test("the sub-project and its tasks go with it")
  func movingAProjectToAViewMovesItsSubtree() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let work = try library.createView("Work")
    library.showView(.default)
    let home = try library.createProject("Home", kind: .parallel)
    let kitchen = try library.createProject("Kitchen", kind: .parallel)
    library.drop([LibraryViewModel.dragPayload(for: kitchen)], on: home)
    library.open(.project(kitchen))
    library.capture("replace the tap")

    library.moveProject(home, toView: work)

    #expect(library.projects.isEmpty)
    library.showView(work)
    library.open(.project(kitchen))
    #expect(library.path == [home, kitchen])
    #expect(library.tasks.map(\.title) == ["replace the tap"])
  }
}
