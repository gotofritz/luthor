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
@Suite("Given Miller columns, when an item is added with one press of the plus button and its card")
struct NewItemCardFlowTests {
  @Test("the title shows in the column as it is typed, and OK makes the task with priority optional and 5 minutes")
  func aTaskIsMadeFromItsCard() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let europe = try library.createProject("Europe", kind: .parallel)
    library.open(.project(europe))

    library.beginNewItem(under: europe, kind: .task)
    library.setNewItemTitle("book fl")
    library.setNewItemTitle("book flights")

    #expect(library.newItem?.card.title == "book flights")
    #expect(library.columns.last?.parentID == europe)
    #expect(library.tasks.isEmpty)
    library.saveNewItem(try #require(library.newItem?.card))

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.open(.project(europe))
    let flights = try #require(relaunched.tasks.first)
    #expect(flights.title == "book flights")
    #expect(flights.priority == .optional)
    #expect(flights.estimate == 5)
  }

  @Test("a project made from the card has no priority and no estimate")
  func aProjectHasNoDefaults() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let europe = try library.createProject("Europe", kind: .parallel)
    library.open(.project(europe))

    library.beginNewItem(under: europe, kind: .task)
    library.setNewItemKind(.project(.sequential))
    library.setNewItemTitle("France")
    library.saveNewItem(try #require(library.newItem?.card))

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    let france = try #require(relaunched.projects.first { $0.title == "France" })
    #expect(france.priority == nil)
    #expect(france.estimate == nil)
  }

  @Test("Add Tasks on a task makes it a project and starts the first task in it, so one OK adds it")
  func addTasksNeedsNoSecondPress() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("plan trip")
    let trip = try library.task("plan trip")

    library.addTasks(to: trip)
    library.setNewItemTitle("book flights")
    library.saveNewItem(try #require(library.newItem?.card))

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.open(.project(trip))
    #expect(relaunched.tasks.map(\.title) == ["book flights"])
    #expect(relaunched.shownProject?.title == "plan trip")
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
