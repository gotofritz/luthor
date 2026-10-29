import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given several tasks in the inbox, when I select more than one")
struct BulkEditFlowTests {
  private func inbox(at url: URL) throws -> (LibraryViewModel, [TaskID]) {
    let library = launchApp(on: url)
    for title in ["call bank", "call mum", "write report"] { library.capture(title) }
    let ids = try ["call bank", "call mum", "write report"].map(library.task)
    return (library, ids)
  }

  @Test("tagging, then undo, takes the tag off all of them at once")
  func taggingAllAtOnceAndUndo() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let (library, ids) = try inbox(at: dir.file("events.jsonl"))
    library.setSelection(Set(ids))

    library.tagSelected(named: "calls")
    for id in ids { #expect(library.tagItems(of: id).map(\.name) == ["calls"]) }

    library.undo()
    for id in ids { #expect(library.tagItems(of: id).isEmpty) }
  }

  @Test("the edit card shows a value only when all agree, and setting one applies it to every task")
  func editCardAppliesToAll() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let (library, ids) = try inbox(at: url)
    library.prioritize(ids[0], as: .critical)
    library.prioritize(ids[1], as: .important)
    library.estimate(ids[0], as: 30)
    library.estimate(ids[1], as: 30)
    library.setSelection(Set(ids[0...1]))

    let card = try #require(library.bulkCard)
    #expect(card.priority == .mixed)
    #expect(card.estimate == .same(30))

    library.applyBulk(BulkEdit(priority: .set(.optional)))
    #expect(library.bulkCard?.priority == .same(.optional))
    let relaunched = launchApp(on: url)
    relaunched.show(.priorities)
    relaunched.selectPriorities([.optional])
    #expect(relaunched.tasks.map(\.title) == ["call bank", "call mum"])

    library.undo()
    #expect(library.bulkCard?.priority == .mixed)
  }

  @Test("dropping drops all of them, and Undo brings them back together")
  func droppingAll() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let (library, ids) = try inbox(at: dir.file("events.jsonl"))
    library.setSelection(Set(ids[0...1]))

    library.dropSelectedTasks()
    #expect(library.tasks.map(\.title) == ["write report"])
    #expect(library.selectedIDs.isEmpty)

    library.undo()
    #expect(library.tasks.count == 3)
  }

  @Test("deleting deletes all of them")
  func deletingAll() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let (library, ids) = try inbox(at: url)
    library.setSelection(Set(ids[1...2]))

    library.deleteSelectedTasks()

    #expect(launchApp(on: url).tasks.map(\.title) == ["call bank"])
  }
}
