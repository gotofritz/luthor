import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given the navigation rail, when I pick a place")
struct NavigationRailFlowTests {
  @Test("the inbox lists its tasks, the projects list the top-level projects")
  func eachPlaceShowsItsFirstColumn() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("buy milk")
    let home = try library.createProject("Home", kind: .parallel)

    library.show(.inbox)
    #expect(library.tasks.map(\.title) == ["buy milk"])

    library.show(.projects)
    #expect(library.columns.first?.entries.map(\.id) == ["project-\(home.rawValue)"])
    #expect(library.path == [])
  }

  @Test("projects opened in the projects place add columns as before")
  func projectsOpenIntoColumns() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let home = try library.createProject("Home", kind: .parallel)

    library.show(.projects)
    library.open(.project(home))

    #expect(library.section == .projects)
    #expect(library.columns.map(\.parentID) == [nil, home])
  }
}

@MainActor
@Suite("Given tasks with priorities, when I pick priorities one after the other")
struct PriorityFlowTests {
  @Test("they add up, and a relaunch still has the priorities on the tasks")
  func pickedPrioritiesAddUp() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    for title in ["pay rent", "call mum", "learn Greek"] { library.capture(title) }
    library.prioritize(try library.task("pay rent"), as: .critical)
    library.prioritize(try library.task("call mum"), as: .important)
    library.prioritize(try library.task("learn Greek"), as: .someday)

    library.show(.priorities)
    library.togglePriority(.important)
    library.togglePriority(.critical)

    #expect(library.tasks.map(\.title) == ["pay rent", "call mum"])

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.show(.priorities)
    relaunched.togglePriority(.someday)
    #expect(relaunched.tasks.map(\.title) == ["learn Greek"])
  }

  @Test("picking a picked priority again drops only that one")
  func pickingAgainDropsOnlyThatPriority() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("pay rent")
    library.capture("call mum")
    library.prioritize(try library.task("pay rent"), as: .critical)
    library.prioritize(try library.task("call mum"), as: .important)
    library.show(.priorities)
    library.togglePriority(.critical)
    library.togglePriority(.important)

    library.togglePriority(.critical)

    #expect(library.tasks.map(\.title) == ["call mum"])
  }
}
