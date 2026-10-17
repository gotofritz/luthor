import LuthorDomain
import LuthorTestSupport
import Testing

private let monday = date("2026-10-19")

private func plan(
  _ events: [EventEnvelope],
  on day: CalendarDate = monday,
  today: CalendarDate = monday
) -> DayPlan {
  LibraryState.replay(events).plan(for: .default, on: day, today: today)
}

/// Two B tasks captured in this order, then whatever a test adds.
private let peers = [
  captured("t1", "pay tax", lamport: 1), prioritized("t1", as: .important, lamport: 2),
  captured("t2", "write report", lamport: 3), prioritized("t2", as: .important, lamport: 4),
]

@Suite("When a hard deadline is due")
struct HardDeadlineRankingTests {
  @Test("it comes ahead of its priority peers among the candidates")
  func itComesAheadOfItsPriorityPeers() {
    let candidates = plan(peers + [dueSet("t2", on: "2026-10-19", lamport: 5)]).candidates

    #expect(candidates.map(\.task.title) == ["write report", "pay tax"])
  }

  @Test("an overdue one does too")
  func anOverdueOneDoesToo() {
    let candidates = plan(peers + [dueSet("t2", on: "2026-10-16", lamport: 5)]).candidates

    #expect(candidates.map(\.task.title) == ["write report", "pay tax"])
  }

  @Test("the earlier deadline comes first")
  func theEarlierDeadlineComesFirst() {
    let candidates = plan(
      peers + [dueSet("t1", on: "2026-10-19", lamport: 5), dueSet("t2", on: "2026-10-16", lamport: 6)]
    ).candidates

    #expect(candidates.map(\.task.title) == ["write report", "pay tax"])
  }

  @Test("it does not pass a higher priority")
  func itDoesNotPassAHigherPriority() {
    let events =
      peers + [
        captured("t3", "call bank", lamport: 5), prioritized("t3", as: .critical, lamport: 6),
        dueSet("t2", on: "2026-10-19", lamport: 7),
      ]

    #expect(plan(events).candidates.map(\.task.title) == ["call bank", "write report", "pay tax"])
  }

  @Test("it also comes first among the tasks planned for the day")
  func itAlsoComesFirstAmongThePlannedTasks() {
    let events =
      peers + [
        scheduled("t1", on: "2026-10-19", lamport: 5), scheduled("t2", on: "2026-10-19", lamport: 6),
        dueSet("t2", on: "2026-10-19", lamport: 7),
      ]

    #expect(plan(events).entries.map(\.task.title) == ["write report", "pay tax"])
  }

  @Test("the order I chose still wins")
  func theOrderIChoseStillWins() {
    let events =
      peers + [
        scheduled("t1", on: "2026-10-19", lamport: 5), scheduled("t2", on: "2026-10-19", lamport: 6),
        planOrdered(["t1", "t2"], on: "2026-10-19", lamport: 7), dueSet("t2", on: "2026-10-19", lamport: 8),
      ]

    #expect(plan(events).entries.map(\.task.title) == ["pay tax", "write report"])
  }

  @Test("its entry says the deadline is why")
  func itsEntrySaysTheDeadlineIsWhy() {
    let candidates = plan(peers + [dueSet("t2", on: "2026-10-16", lamport: 5)]).candidates

    #expect(candidates.map(\.reason) == ["B priority, deadline 2026-10-16", "B priority"])
  }

  @Test("it never plans the task by itself")
  func itNeverPlansTheTaskByItself() {
    let day = plan(peers + [dueSet("t2", on: "2026-10-19", lamport: 5)])

    #expect(day.entries.isEmpty)
  }

  @Test("an unclarified task is offered too, so a deadline is not missed")
  func anUnclarifiedTaskIsOfferedToo() {
    let events = [captured("t1", "renew passport", lamport: 1), dueSet("t1", on: "2026-10-19", lamport: 2)]

    #expect(plan(events).candidates.map(\.task.title) == ["renew passport"])
  }

  @Test("a someday task is not offered, deadline or not")
  func aSomedayTaskIsNotOffered() {
    let events = peers + [prioritized("t2", as: .someday, lamport: 5), dueSet("t2", on: "2026-10-19", lamport: 6)]

    #expect(plan(events).candidates.map(\.task.title) == ["pay tax"])
  }

  @Test("the day it is planned for still takes it out of the candidates")
  func thePlannedDayStillTakesItOutOfTheCandidates() {
    let day = plan(peers + [dueSet("t2", on: "2026-10-19", lamport: 5), scheduled("t2", on: "2026-10-19", lamport: 6)])

    #expect(day.candidates.map(\.task.title) == ["pay tax"])
    #expect(day.entries.map(\.reason) == ["B priority, deadline 2026-10-19"])
  }
}

@Suite("When a deadline is not due yet, or not a deadline")
struct OtherDueDatesRankingTests {
  @Test("a hard deadline after the day shown changes nothing")
  func aHardDeadlineAfterTheDayShownChangesNothing() {
    let candidates = plan(peers + [dueSet("t2", on: "2026-10-20", lamport: 5)]).candidates

    #expect(candidates.map(\.task.title) == ["pay tax", "write report"])
    #expect(candidates.map(\.reason) == ["B priority", "B priority"])
  }

  @Test("it is due on the day shown, whichever day it is today")
  func itIsDueOnTheDayShown() {
    let events = peers + [dueSet("t2", on: "2026-10-20", lamport: 5)]

    #expect(plan(events, on: date("2026-10-20")).candidates.map(\.task.title) == ["write report", "pay tax"])
  }

  @Test("a target date changes nothing, however close")
  func aTargetDateChangesNothing() {
    let candidates = plan(peers + [dueSet("t2", on: "2026-10-16", hard: false, lamport: 5)]).candidates

    #expect(candidates.map(\.task.title) == ["pay tax", "write report"])
    #expect(candidates.map(\.reason) == ["B priority", "B priority"])
  }

  @Test("an unclarified task with a target date or a later deadline stays out")
  func anUnclarifiedTaskStaysOut() {
    let events = [
      captured("t1", "renew passport", lamport: 1), dueSet("t1", on: "2026-10-16", hard: false, lamport: 2),
      captured("t2", "file taxes", lamport: 3), dueSet("t2", on: "2026-10-20", lamport: 4),
    ]

    #expect(plan(events).candidates.isEmpty)
  }
}
