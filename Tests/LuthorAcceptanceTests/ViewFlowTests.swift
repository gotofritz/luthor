import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given a Work view next to the default view")
struct ViewIsolationFlowTests {
  @Test("tasks and projects of one view never show in the other, after a relaunch too")
  func nothingLeaksBetweenViews() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let work = try library.createView("Work")
    library.capture("write the report")
    _ = try library.createProject("Q4 plan", kind: .parallel)

    library.showView(.default)
    library.capture("buy milk")
    _ = try library.createProject("Holiday", kind: .parallel)

    #expect(library.tasks.map(\.title) == ["buy milk"])
    #expect(library.projects.map(\.title) == ["Holiday"])
    let atWork = launchApp(on: dir.file("events.jsonl"), view: work)
    #expect(atWork.views.map(\.name) == ["Default", "Work"])
    #expect(atWork.tasks.map(\.title) == ["write the report"])
    #expect(atWork.projects.map(\.title) == ["Q4 plan"])
  }
}

@MainActor
@Suite("Given a log written before views existed")
struct PreViewLogFlowTests {
  @Test("its tasks and projects show in the default view")
  func oldLogReplaysIntoTheDefaultView() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let lines = [
      #"{"data":{"taskID":"t1","title":"buy milk"},"device":"mac","id":"e1","lamport":1,"type":"TaskCaptured"}"#,
      #"{"data":{"kind":"parallel","taskID":"p1","title":"Holiday"},"device":"mac","id":"e2","lamport":2,"type":"TaskCaptured"}"#,
    ]
    try (lines.joined(separator: "\n") + "\n").write(to: dir.file("events.jsonl"), atomically: true, encoding: .utf8)

    let library = launchApp(on: dir.file("events.jsonl"))

    #expect(library.views.map(\.name) == ["Default"])
    #expect(library.tasks.map(\.title) == ["buy milk"])
    #expect(library.projects.map(\.title) == ["Holiday"])
  }
}

@MainActor
@Suite("Given a task in the default view and a project in Work")
struct CrossViewMoveFlowTests {
  @Test("filing the task into the project is refused, and moving it to Work takes it across")
  func onlyAMoveToTheViewCrossesOver() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("write the report")
    let task = try library.task("write the report")
    let work = try library.createView("Work")
    let plan = try library.createProject("Q4 plan", kind: .parallel)
    library.showView(.default)

    library.file(task, into: plan)
    #expect(library.tasks.map(\.title) == ["write the report"])

    library.move(task, toView: work)
    #expect(library.tasks.isEmpty)
    library.showView(work)
    #expect(library.tasks.map(\.title) == ["write the report"])
    library.file(task, into: plan)
    library.open(.project(plan))
    #expect(library.tasks.map(\.title) == ["write the report"])
  }
}
