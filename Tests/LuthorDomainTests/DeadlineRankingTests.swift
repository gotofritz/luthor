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

@Suite("When a due date is due")
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

  @Test("it can pass a higher priority that has no deadline")
  func itCanPassAHigherPriority() {
    let events =
      peers + [
        captured("t3", "call bank", lamport: 5), prioritized("t3", as: .critical, lamport: 6),
        dueSet("t2", on: "2026-10-19", lamport: 7),
      ]

    #expect(plan(events).candidates.map(\.task.title) == ["write report", "call bank", "pay tax"])
  }

  @Test("a critical task due in six months ranks below a nearer important one")
  func aFarCriticalTaskRanksBelowANearerImportantOne() {
    let events =
      peers + [
        captured("t3", "call bank", lamport: 5), prioritized("t3", as: .critical, lamport: 6),
        dueSet("t3", on: "2027-04-19", lamport: 7), dueSet("t2", on: "2026-10-26", lamport: 8),
      ]

    #expect(plan(events).candidates.map(\.task.title) == ["write report", "pay tax", "call bank"])
  }

  @Test("a critical task due in six months ranks below important ones with no deadline")
  func aFarCriticalTaskRanksBelowUndatedImportantOnes() {
    let events =
      peers + [
        captured("t3", "call bank", lamport: 5), prioritized("t3", as: .critical, lamport: 6),
        dueSet("t3", on: "2027-04-19", lamport: 7),
      ]

    #expect(plan(events).candidates.map(\.task.title) == ["pay tax", "write report", "call bank"])
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

    #expect(candidates.map(\.reason) == ["B priority, due 2026-10-16", "B priority"])
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
    #expect(day.entries.map(\.reason) == ["B priority, due 2026-10-19"])
  }
}

@Suite("When a due date is not due yet")
struct OtherDueDatesRankingTests {
  @Test("a hard deadline after the day shown still ranks the task by how soon it is")
  func aLaterHardDeadlineStillRanks() {
    let candidates = plan(peers + [dueSet("t2", on: "2026-10-20", lamport: 5)]).candidates

    #expect(candidates.map(\.task.title) == ["write report", "pay tax"])
    #expect(candidates.map(\.reason) == ["B priority, due 2026-10-20", "B priority"])
  }

  @Test("a hard deadline more than a quarter off ranks below the same priority with none")
  func aFarHardDeadlineRanksBelowNone() {
    let candidates = plan(peers + [dueSet("t1", on: "2027-04-19", lamport: 5)]).candidates

    #expect(candidates.map(\.task.title) == ["write report", "pay tax"])
  }

  @Test("it is due on the day shown, whichever day it is today")
  func itIsDueOnTheDayShown() {
    let events = peers + [dueSet("t2", on: "2026-10-20", lamport: 5)]

    #expect(plan(events, on: date("2026-10-20")).candidates.map(\.task.title) == ["write report", "pay tax"])
  }

  @Test("a target date ranks the task like a deadline, and the entry says it is a target")
  func aTargetDateRanksLikeADeadline() {
    let candidates = plan(peers + [dueSet("t2", on: "2026-10-16", hard: false, lamport: 5)]).candidates

    #expect(candidates.map(\.task.title) == ["write report", "pay tax"])
    #expect(candidates.map(\.reason) == ["B priority, due 2026-10-16", "B priority"])
  }

  @Test("a target date more than a quarter off ranks below the same priority with none")
  func aFarTargetDateRanksBelowNone() {
    let candidates = plan(peers + [dueSet("t1", on: "2027-04-19", hard: false, lamport: 5)]).candidates

    #expect(candidates.map(\.task.title) == ["write report", "pay tax"])
  }

  @Test("an unclarified task with a later due date stays out")
  func anUnclarifiedTaskStaysOut() {
    let events = [captured("t2", "file taxes", lamport: 3), dueSet("t2", on: "2026-10-20", lamport: 4)]

    #expect(plan(events).candidates.isEmpty)
  }
}
