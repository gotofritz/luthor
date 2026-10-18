import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given a task with a priority, an estimate, a due date and a tag, when tasks are added to it")
struct TaskThatGrowsChildrenFlowTests {
  @Test("it keeps all of them as a project and shows in Projects rather than the inbox, after a relaunch too")
  func theFieldsSurviveAsAProject() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("plan trip")
    let trip = try library.task("plan trip")
    let due = DueDate(date: date("2027-04-01"), isHard: true)
    library.saveCard(
      ofTask: trip,
      TaskCardDraft(
        title: "plan trip", priority: .important, estimate: 120, due: due, notes: "Lisbon", tags: ["travel"]))

    library.addTasks(to: trip)
    library.capture("book flights")
    library.capture("renew passport")

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    #expect(relaunched.tasks.isEmpty)
    let project = try #require(relaunched.projects.first)
    #expect(project.id == trip)
    #expect(project.priority == .important)
    #expect(project.estimate == 120)
    #expect(relaunched.dueDate(of: trip) == due)
    #expect(relaunched.tagItems(of: trip).map(\.name) == ["travel"])
    relaunched.open(.project(trip))
    #expect(relaunched.tasks.map(\.title) == ["book flights", "renew passport"])
  }
}

@MainActor
@Suite("Given a project, when its card is edited like a task's")
struct ProjectCardFieldsFlowTests {
  @Test("its priority, estimate, due date and tags are kept, after a relaunch too")
  func theProjectKeepsTheFields() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let move = try library.createProject("Move house", kind: .parallel)
    let due = DueDate(date: date("2027-03-01"), isHard: false)

    library.saveCard(
      ofProject: move,
      TaskCardDraft(title: "Move house", priority: .critical, estimate: 600, due: due, notes: "", tags: ["home"]),
      kind: .sequential)

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    let project = try #require(relaunched.projects.first)
    #expect(project.priority == .critical)
    #expect(project.estimate == 600)
    #expect(project.kind == .sequential)
    #expect(relaunched.dueDate(of: move) == due)
    #expect(relaunched.tagItems(of: move).map(\.name) == ["home"])
  }
}

@MainActor
@Suite("Given a task, when another task is filed under it")
struct FileUnderATaskFlowTests {
  @Test("the task holds it as a project, after a relaunch too")
  func theTaskBecomesAContainer() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("garden")
    library.capture("water the plants")
    let garden = try library.task("garden")
    let water = try library.task("water the plants")

    library.file(water, into: garden)

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    #expect(relaunched.projects.map(\.id) == [garden])
    relaunched.open(.project(garden))
    #expect(relaunched.tasks.map(\.title) == ["water the plants"])
  }
}
