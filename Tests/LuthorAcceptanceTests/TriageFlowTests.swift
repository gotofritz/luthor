import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given the inbox, when a task is captured and triaged")
struct TriageFlowTests {
  @Test("the quick-capture syntax gives it a priority and an estimate at capture speed")
  func quickCaptureGivesPriorityAndEstimate() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))

    library.capture("call bank !a 15m")
    library.capture("buy milk")

    // Clarified by capture: out of the inbox straight away.
    #expect(library.tasks.map(\.title) == ["buy milk"])

    library.show(.priorities)
    library.togglePriority(.critical)
    #expect(library.tasks.map(\.title) == ["call bank"])
    #expect(library.tasks.first?.estimate == 15)
  }

  @Test("giving a task a priority by hand also clarifies it out of the inbox")
  func prioritizingByHandClarifiesIt() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("pay rent")
    library.capture("call mum")

    library.prioritize(try library.task("pay rent"), as: .important)

    #expect(library.tasks.map(\.title) == ["call mum"])
  }

  @Test("a someday task is kept out of next actions until it is promoted")
  func somedayTaskIsKeptOutOfNextActionsUntilPromoted() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let project = try library.createProject("Trip", kind: .parallel)
    library.capture("book flights")
    let task = try library.task("book flights")
    library.file(task, into: project)
    library.prioritize(task, as: .someday)
    library.open(.project(project))

    #expect(library.nextActions.isEmpty)

    library.prioritize(task, as: .important)

    #expect(library.nextActions == [task])
  }
}
