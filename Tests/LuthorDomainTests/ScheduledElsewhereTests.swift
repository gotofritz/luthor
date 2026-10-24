import LuthorDomain
import LuthorTestSupport
import Testing

private let monday = date("2026-10-19")

@Suite("When a task is scheduled for another day")
struct ScheduledElsewhereTests {
  private let events = [
    captured("t1", "write report", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
    captured("t2", "call bank", lamport: 3), prioritized("t2", as: .optional, lamport: 4),
    captured("t3", "pay tax", lamport: 5), prioritized("t3", as: .important, lamport: 6),
    scheduled("t1", on: "2026-10-21", lamport: 7),
  ]

  @Test("it is a candidate after all the others, however high its priority")
  func itComesLast() {
    let plan = LibraryState.replay(events).plan(for: .default, on: monday, today: monday)

    #expect(plan.candidates.map(\.task.title) == ["pay tax", "call bank", "write report"])
  }

  @Test("on its own day it is in the plan, not among the candidates")
  func onItsOwnDayItIsPlanned() {
    let plan = LibraryState.replay(events).plan(for: .default, on: date("2026-10-21"), today: monday)

    #expect(plan.entries.map(\.task.title) == ["write report"])
    #expect(plan.candidates.map(\.task.title) == ["pay tax", "call bank"])
  }

  @Test("a due date is only a way to rank: it plans nothing")
  func aDueDatePlansNothing() {
    let plan = LibraryState.replay(events + [dueSet("t3", on: "2026-10-19", lamport: 8)])
      .plan(for: .default, on: monday, today: monday)

    #expect(plan.entries.isEmpty)
    #expect(plan.candidates.first?.task.title == "pay tax")
  }
}
