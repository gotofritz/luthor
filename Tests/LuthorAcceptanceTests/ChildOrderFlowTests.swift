import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given a sequential project with three steps, when the steps are put in order")
struct ChildOrderFlowTests {
  @Test("moving a step changes the next action, after a relaunch too")
  func movingAStepChangesTheNextAction() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let move = try library.createProject("Move house", kind: .sequential)
    library.open(.project(move))
    library.capture("find a flat")
    library.capture("sign the lease")
    library.capture("book a van")
    let first = try library.task("find a flat")
    let last = try library.task("book a van")
    #expect(library.nextActions == [first])

    library.moveDown(first)
    library.moveUp(last)

    #expect(library.tasks.map(\.title) == ["sign the lease", "book a van", "find a flat"])
    #expect(library.nextActions == [try library.task("sign the lease")])
    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.open(.project(move))
    #expect(relaunched.tasks.map(\.title) == ["sign the lease", "book a van", "find a flat"])
  }
}

@MainActor
@Suite("Given a project with tasks, when its header bar is clicked")
struct ListSortFlowTests {
  @Test("a click on a cell sorts by it, a second turns the order round, and nothing is written to the log")
  func headerSortsTheList() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let shop = try library.createProject("Shopping", kind: .parallel)
    library.open(.project(shop))
    library.capture("milk")
    library.capture("Apples")
    library.capture("eggs")
    library.prioritize(try library.task("eggs"), as: .critical)
    library.estimate(try library.task("milk"), as: 5)
    let column = "project-\(shop.rawValue)"
    let titles = {
      library.columns.last?.entries.compactMap { entry -> String? in
        guard case .task(let task) = entry else { return nil }
        return task.title
      } ?? []
    }

    library.sortBy(.title, ofList: column)
    #expect(titles() == ["Apples", "eggs", "milk"])

    library.sortBy(.title, ofList: column)
    #expect(titles() == ["milk", "eggs", "Apples"])

    library.sortBy(.priority, ofList: column)
    #expect(titles() == ["eggs", "milk", "Apples"])

    library.sortBy(.duration, ofList: column)
    #expect(titles() == ["milk", "Apples", "eggs"])

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.open(.project(shop))
    #expect(relaunched.tasks.map(\.title) == ["milk", "Apples", "eggs"])
  }
}
