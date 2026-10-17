import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

// Monday 2026-10-19 is the day the window is launched on.

@MainActor
@Suite("Given tasks of the same priority, when one has a hard deadline")
struct HardDeadlineFlowTests {
  @Test("it comes first among Today's candidates once the deadline is due, and stays so after a relaunch")
  func itComesFirstOnceTheDeadlineIsDue() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let library = launchApp(on: url)
    library.capture("pay tax")
    library.capture("write report")
    let tax = try library.task("pay tax")
    let report = try library.task("write report")
    library.prioritize(tax, as: .important)
    library.prioritize(report, as: .important)
    library.show(.today)
    #expect(library.plan.candidates.map(\.task.title) == ["pay tax", "write report"])

    library.setDue(report, to: date("2026-10-19"), isHard: true)

    #expect(library.plan.candidates.map(\.task.title) == ["write report", "pay tax"])
    #expect(library.plan.candidates.map(\.reason) == ["B priority, deadline 2026-10-19", "B priority"])
    let relaunched = launchApp(on: url)
    relaunched.show(.today)
    #expect(relaunched.plan.candidates.map(\.task.title) == ["write report", "pay tax"])
  }

  @Test("a deadline still ahead leaves the order alone, and the day it comes due changes it")
  func aDeadlineStillAheadLeavesTheOrderAlone() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("pay tax")
    library.capture("write report")
    let tax = try library.task("pay tax")
    let report = try library.task("write report")
    library.prioritize(tax, as: .important)
    library.prioritize(report, as: .important)
    library.setDue(report, to: date("2026-10-21"), isHard: true)
    library.show(.today)
    #expect(library.plan.candidates.map(\.task.title) == ["pay tax", "write report"])

    library.showDay(date("2026-10-21"))

    #expect(library.plan.candidates.map(\.task.title) == ["write report", "pay tax"])
  }

  @Test("a due date alone never plans the task")
  func aDueDateAloneNeverPlansTheTask() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("pay tax")
    let tax = try library.task("pay tax")

    library.setDue(tax, to: date("2026-10-19"), isHard: true)
    library.show(.today)

    #expect(library.plan.entries.isEmpty)
    #expect(library.plan.candidates.map(\.task.title) == ["pay tax"])
  }

  @Test("a target date does not reorder anything")
  func aTargetDateDoesNotReorderAnything() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("pay tax")
    library.capture("write report")
    let tax = try library.task("pay tax")
    let report = try library.task("write report")
    library.prioritize(tax, as: .important)
    library.prioritize(report, as: .important)

    library.setDue(report, to: date("2026-10-19"), isHard: false)
    library.show(.today)

    #expect(library.plan.candidates.map(\.task.title) == ["pay tax", "write report"])
  }
}

@MainActor
@Suite("Given a task card, when I give the task a due date")
struct DueDateCardFlowTests {
  @Test("OK keeps it, and a relaunch still has it; clearing it takes it away")
  func okKeepsItAndClearingTakesItAway() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let library = launchApp(on: url)
    library.capture("pay tax")
    let tax = try library.task("pay tax")
    library.selection = tax
    #expect(library.dueDate(of: tax) == nil)

    library.editCard(.task(tax))
    library.saveCard(
      ofTask: tax, title: "pay tax", priority: nil, estimate: nil,
      due: DueDate(date: date("2026-10-30"), isHard: true), notes: "")

    let relaunched = launchApp(on: url)
    let again = try relaunched.task("pay tax")
    #expect(relaunched.dueDate(of: again) == DueDate(date: date("2026-10-30"), isHard: true))

    relaunched.editCard(.task(again))
    relaunched.saveCard(ofTask: again, title: "pay tax", priority: nil, estimate: nil, due: nil, notes: "")
    #expect(relaunched.dueDate(of: again) == nil)
  }

  @Test("Cancel keeps nothing")
  func cancelKeepsNothing() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("pay tax")
    let tax = try library.task("pay tax")
    library.selection = tax

    library.editCard(.task(tax))
    library.cancelCardEdit()

    #expect(library.dueDate(of: tax) == nil)
    #expect(library.editingCard == nil)
  }
}
