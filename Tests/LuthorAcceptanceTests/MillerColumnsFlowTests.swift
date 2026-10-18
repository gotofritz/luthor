import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given Miller columns, when items are added with the plus button of a column")
struct ColumnPlusButtonFlowTests {
  @Test("projects, sub-projects and tasks land in the column they were added to, after a relaunch too")
  func itemsLandInTheirColumn() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let europe = try library.createProject("Europe", kind: .parallel)
    library.open(.project(europe))

    library.addProject(titled: "France", kind: .sequential, under: europe)
    library.addTask(titled: "book flights", to: europe)

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.open(.project(europe))
    #expect(relaunched.tasks.map(\.title) == ["book flights"])
    #expect(relaunched.projects.map(\.title) == ["Europe", "France"])
    #expect(relaunched.columns.first?.entries.count == 1)
    #expect(relaunched.columns.last?.entries.count == 2)
  }
}

@MainActor
@Suite("Given a project with a task, when the columns are clicked")
struct ColumnCardFlowTests {
  @Test("the last column shows the task card, and the parent project again brings the project card back")
  func parentProjectDeselectsTheTask() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let europe = try library.createProject("Europe", kind: .parallel)
    library.open(.project(europe))
    library.addTask(titled: "book flights", to: europe)
    let flights = try library.task("book flights")

    #expect(library.cardTarget == .project(europe))
    library.selection = flights
    #expect(library.cardTarget == .task(flights))

    library.open(.project(europe))

    #expect(library.selection == nil)
    #expect(library.cardTarget == .project(europe))
  }
}

@MainActor
@Suite("Given a card, when notes are added and deleted without editing")
struct CardNotesFlowTests {
  @Test("they are bullets, each deletable, after a relaunch too")
  func notesAreDeletableBullets() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let europe = try library.createProject("Europe", kind: .parallel)
    library.open(.project(europe))
    library.addTask(titled: "book flights", to: europe)
    let flights = try library.task("book flights")

    library.appendNote("check prices", to: flights)
    library.appendNote("ask Sam about https://example.com/air", to: flights)
    library.appendNote("pick a seat", to: flights)
    library.appendNote("visit in spring", to: europe)
    library.deleteNote(at: 1, of: flights)

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.open(.project(europe))
    #expect(NoteBullets.bullets(in: relaunched.tasks.first?.notes) == ["check prices", "pick a seat"])
    #expect(NoteBullets.bullets(in: relaunched.shownProject?.notes) == ["visit in spring"])
  }
}
