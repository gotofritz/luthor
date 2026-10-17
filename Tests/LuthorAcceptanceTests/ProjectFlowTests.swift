import Foundation
import LuthorCLI
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given tasks in the inbox, when one is filed into a new project")
struct InboxProcessingFlowTests {
  @Test("the inbox no longer shows it and the project does, after a relaunch too")
  func filedTaskMovesFromInboxToProject() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("book flights")
    library.capture("buy milk")
    let holiday = try library.createProject("Holiday", kind: .parallel)

    library.selection = try library.task("book flights")
    library.fileSelected(into: holiday)

    #expect(library.tasks.map(\.title) == ["buy milk"])
    let relaunched = launchApp(on: dir.file("events.jsonl"))
    #expect(relaunched.projects.map(\.title) == ["Holiday"])
    #expect(relaunched.tasks.map(\.title) == ["buy milk"])
    relaunched.open(.project(holiday))
    #expect(relaunched.tasks.map(\.title) == ["book flights"])
  }
}

@MainActor
@Suite("Given a sequential project with three tasks")
struct SequentialProjectFlowTests {
  @Test("only the first is the next action, and completing it makes the second one next")
  func completingTheNextActionPromotesTheNextTask() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let move = try library.createProject("Move house", kind: .sequential)
    library.open(.project(move))
    library.capture("find a flat")
    library.capture("sign the lease")
    library.capture("book a van")
    let first = try library.task("find a flat")
    let second = try library.task("sign the lease")

    #expect(library.nextActions == [first])
    library.complete(first)

    #expect(library.nextActions == [second])
  }
}

@MainActor
@Suite("Given a parallel project with three tasks")
struct ParallelProjectFlowTests {
  @Test("every task is a next action")
  func everyTaskIsANextAction() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let garden = try library.createProject("Garden", kind: .parallel)
    library.open(.project(garden))
    library.capture("mow the lawn")
    library.capture("prune the roses")
    library.capture("fix the fence")

    #expect(library.nextActions == Set(library.tasks.map(\.id)))
    #expect(library.tasks.count == 3)
  }
}

@MainActor
@Suite("Given a project with an open task, when the project is completed")
struct ProjectCompletionFlowTests {
  @Test("it leaves the projects list and its task is no longer open")
  func completedProjectAndItsTasksAreGone() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let taxes = try library.createProject("Taxes", kind: .parallel)
    library.open(.project(taxes))
    library.capture("file the return")

    library.completeProject(taxes)

    #expect(library.projects.isEmpty)
    #expect(library.sidebarSelection == .inbox)
    let cli = CLI(
      environment: ["LUTHOR_LOG": dir.file("events.jsonl").path, "LUTHOR_DEVICE_ID": "mac"],
      home: dir.file("home"),
      ids: SequentialIDs()
    )
    #expect(cli.run(["list"]) == CLIResult(exitCode: 0, output: ""))
  }
}
