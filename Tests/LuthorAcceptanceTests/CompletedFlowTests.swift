import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given a completed project and a completed task")
struct CompletedFlowTests {
  @Test("they disappear, show again with the completed toggle, and survive a relaunch")
  func completedItemsCanBeShownAgain() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let holiday = try library.createProject("Holiday", kind: .parallel)
    library.capture("buy milk")
    library.complete(try library.task("buy milk"))
    library.completeProject(holiday)
    #expect(library.columns.first?.entries.isEmpty == true)
    #expect(library.tasks.isEmpty)

    library.showCompleted = true

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.showCompleted = true
    #expect(relaunched.columns.first?.entries.map(\.id) == ["project-\(holiday.rawValue)"])
    #expect(relaunched.tasks.map(\.title) == ["buy milk"])
    #expect(relaunched.completedProjectIDs == [holiday])
  }

  @Test("reopening them brings them back for good, with the toggle off")
  func reopenedItemsStayOpen() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let holiday = try library.createProject("Holiday", kind: .parallel)
    library.open(.project(holiday))
    library.capture("book flights")
    library.completeProject(holiday)
    library.showCompleted = true

    library.reopenProject(holiday)
    library.showCompleted = false

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.open(.project(holiday))
    #expect(relaunched.columns.first?.entries.map(\.id) == ["project-\(holiday.rawValue)"])
    #expect(relaunched.tasks.map(\.title) == ["book flights"])
  }
}
