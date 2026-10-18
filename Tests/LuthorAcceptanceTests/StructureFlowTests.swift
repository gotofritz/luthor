import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given a task with a priority, an estimate and notes, when it is duplicated")
struct DuplicateTaskFlowTests {
  @Test("a copy with the same card is listed next to it and selected, after a relaunch too")
  func theCopySurvivesARelaunch() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let shop = try library.createProject("Shopping", kind: .parallel)
    library.open(.project(shop))
    library.capture("buy milk")
    let milk = try library.task("buy milk")
    library.prioritize(milk, as: .important)
    library.estimate(milk, as: 5)
    library.setNotes(milk, to: "oat")

    library.duplicate(milk)

    #expect(library.tasks.map(\.title) == ["buy milk", "buy milk"])
    let copy = try #require(library.tasks.last)
    #expect(copy.id != milk)
    #expect(library.selection == copy.id)
    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.open(.project(shop))
    let copies = relaunched.tasks.filter { $0.title == "buy milk" }
    #expect(copies.map(\.priority) == [.important, .important])
    #expect(copies.map(\.estimate) == [5, 5])
    #expect(copies.map(\.notes) == ["oat", "oat"])
  }
}

@MainActor
@Suite("Given tasks and projects, when they are deleted for good")
struct DeleteFlowTests {
  @Test("a task, open or completed, is gone from every list, after a relaunch too")
  func tasksAreGoneAfterARelaunch() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("test task")
    library.capture("old task")
    library.capture("keep me")
    library.complete(try library.task("old task"))
    library.showCompleted = true
    #expect(library.completedTaskIDs.count == 1)

    library.deleteTask(try library.task("test task"))
    library.deleteTask(try #require(library.tasks.first { $0.title == "old task" }).id)

    #expect(library.tasks.map(\.title) == ["keep me"])
    #expect(library.completedTaskIDs.isEmpty)
    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.showCompleted = true
    #expect(relaunched.tasks.map(\.title) == ["keep me"])
    #expect(relaunched.completedTaskIDs.isEmpty)
  }

  @Test("a project goes with its sub-projects and tasks, and the others stay, after a relaunch too")
  func projectsAreGoneWithTheirContents() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let test = try library.createProject("Test project", kind: .parallel)
    let garden = try library.createProject("Garden", kind: .parallel)
    library.open(.project(test))
    library.capture("test task")
    library.addProject(titled: "Test sub-project", kind: .parallel, under: test)
    library.open(.project(garden))
    library.capture("water")

    library.deleteProject(test)

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    #expect(relaunched.columns.first?.entries.map(\.id) == ["project-\(garden.rawValue)"])
    relaunched.open(.project(garden))
    #expect(relaunched.tasks.map(\.title) == ["water"])
    relaunched.showCompleted = true
    relaunched.open(.inbox)
    #expect(relaunched.tasks.isEmpty)
    #expect(relaunched.knownProjects.map(\.title) == ["Garden"])
  }
}

@MainActor
@Suite("Given a task, when tasks are added to it")
struct AddTasksFlowTests {
  @Test("it becomes a project that holds them, after a relaunch too")
  func theTaskBecomesAProject() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"), today: date("2026-10-19"))
    library.capture("plan trip")
    let trip = try library.task("plan trip")
    library.setNotes(trip, to: "in spring")

    library.addTasks(to: trip)
    library.capture("book flights")
    library.capture("renew passport")

    #expect(library.shownProject?.title == "plan trip")
    #expect(library.tasks.map(\.title) == ["book flights", "renew passport"])
    let relaunched = launchApp(on: dir.file("events.jsonl"))
    #expect(relaunched.tasks.isEmpty)
    let project = try #require(relaunched.projects.first)
    #expect(project.title == "plan trip")
    #expect(project.notes == "in spring")
    #expect(project.createdOn == date("2026-10-19"))
    relaunched.open(.project(project.id))
    #expect(relaunched.tasks.map(\.title) == ["book flights", "renew passport"])
  }
}
