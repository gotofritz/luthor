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

  @Test("sorting by title and then by priority lists them in that order, and undo puts the list back")
  func sortingAndUndoing() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let shop = try library.createProject("Shopping", kind: .parallel)
    library.open(.project(shop))
    library.capture("milk")
    library.capture("Apples")
    library.capture("eggs")
    library.prioritize(try library.task("eggs"), as: .critical)

    library.sortChildren(of: shop, by: .title(ascending: true))
    #expect(library.tasks.map(\.title) == ["Apples", "eggs", "milk"])

    library.sortChildren(of: shop, by: .title(ascending: false))
    #expect(library.tasks.map(\.title) == ["milk", "eggs", "Apples"])

    library.sortChildren(of: shop, by: .priority)
    #expect(library.tasks.map(\.title) == ["eggs", "milk", "Apples"])

    library.undo()
    #expect(library.tasks.map(\.title) == ["milk", "eggs", "Apples"])
  }
}
