import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given commands run in a session, when the user presses Undo and Redo")
struct UndoFlowTests {
  @Test("a dropped task comes back on Undo and goes again on Redo, as events appended to the log")
  func droppedTaskComesBackAndGoesAgain() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let library = launchApp(on: url)
    library.capture("call bank")
    let task = try library.task("call bank")
    let before = try JSONLinesEventLog(fileURL: url).readAll().count

    library.dropTask(task)
    #expect(library.tasks.isEmpty)
    #expect(library.canUndo)

    library.undo()
    #expect(library.tasks.map(\.title) == ["call bank"])
    #expect(library.canRedo)

    library.redo()
    #expect(library.tasks.isEmpty)
    #expect(!library.canRedo)

    // Nothing written is touched: the drop, its undo and its redo are all in the log, and a relaunch agrees.
    #expect(try JSONLinesEventLog(fileURL: url).readAll().count == before + 3)
    #expect(launchApp(on: url).tasks.isEmpty)
  }

  @Test("there is no limit: many commands are undone one by one, latest first")
  func manyCommandsAreUndoneInReverse() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("draft 0")
    let task = try library.task("draft 0")

    for number in 1...50 { library.rename(task, to: "draft \(number)") }
    #expect(library.tasks.first?.title == "draft 50")

    for number in stride(from: 49, through: 0, by: -1) {
      library.undo()
      #expect(library.tasks.first?.title == "draft \(number)")
    }
    #expect(!library.canUndo)
  }

  @Test("a new command after an Undo empties Redo")
  func newCommandEmptiesRedo() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("write report")
    let task = try library.task("write report")
    library.rename(task, to: "write the report")
    library.undo()
    #expect(library.canRedo)

    library.rename(task, to: "draft the report")

    #expect(!library.canRedo)
  }
}
