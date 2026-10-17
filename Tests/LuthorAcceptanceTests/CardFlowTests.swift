import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given a task, when its card is edited")
struct TaskCardFlowTests {
  @Test("the new title and notes are kept, after a relaunch too")
  func titleAndNotesSurviveARelaunch() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("buy mlik")
    let milk = try library.task("buy mlik")
    library.selection = milk

    library.rename(milk, to: "buy milk")
    library.setNotes(milk, to: "oat, see https://example.com/milk")

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.selection = milk
    #expect(relaunched.selectedTask?.title == "buy milk")
    let notes = try #require(relaunched.selectedTask?.notes)
    #expect(NoteLinks.links(in: notes).map(\.url) == [URL(string: "https://example.com/milk")])
  }

  @Test("a completed task shows its card too, and keeps it when reopened")
  func completedTaskKeepsItsCard() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("buy milk")
    let milk = try library.task("buy milk")
    library.setNotes(milk, to: "oat")
    library.complete(milk)
    library.showCompleted = true
    library.selection = milk
    #expect(library.selectedTask?.notes == "oat")

    library.reopen(milk)

    #expect(library.selectedTask?.notes == "oat")
    #expect(library.completedTaskIDs.isEmpty)
  }
}

@MainActor
@Suite("Given a parallel project, when its card makes it sequential")
struct ProjectCardFlowTests {
  @Test("only its first task is a next action, after a relaunch too")
  func sequentialKindSurvivesARelaunch() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let move = try library.createProject("Move house", kind: .parallel)
    library.open(.project(move))
    library.capture("find a flat")
    library.capture("sign the lease")
    #expect(library.nextActions.count == 2)

    library.setKind(of: move, to: .sequential)
    library.renameProject(move, to: "Move to Lisbon")
    library.setNotes(ofProject: move, to: "deadline in March")

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.open(.project(move))
    #expect(relaunched.shownProject?.title == "Move to Lisbon")
    #expect(relaunched.shownProject?.kind == .sequential)
    #expect(relaunched.shownProject?.notes == "deadline in March")
    #expect(relaunched.nextActions.count == 1)
    #expect(relaunched.columns.last?.entries.count == 2)
  }
}
