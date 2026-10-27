import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let monday = date("2026-10-19")

@MainActor
private func makeLibrary(_ events: [EventEnvelope], now: Int) -> LibraryViewModel {
  let library = LibraryViewModel(
    log: InMemoryEventLog(events), commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
    today: { monday }, now: { now })
  library.reload()
  library.show(.today)
  return library
}

/// "write report" (60m) starts at 09:00 on Monday, with the time of the other tasks following.
private let reportAtNine = [
  captured("t1", "write report", lamport: 1), estimated("t1", as: 60, lamport: 2),
  scheduled("t1", on: "2026-10-19", lamport: 3), startSet("t1", 540, on: "2026-10-19", lamport: 4),
]

@MainActor
@Suite("When a task is split in two")
struct SplitTaskTests {
  @Test("under way, A ends now and B takes the rest of the time from now")
  func underWayAEndsNow() {
    let library = makeLibrary(reportAtNine, now: 570)

    #expect(
      library.splitDefaults(of: TaskID("t1")) == SplitTimes(aStart: 540, aEnd: 570, bStart: 570, bEnd: 600))
  }

  @Test("not under way, A keeps its end and B is half an hour from now")
  func notUnderWayAKeepsItsEnd() {
    let library = makeLibrary(reportAtNine, now: 480)

    #expect(
      library.splitDefaults(of: TaskID("t1")) == SplitTimes(aStart: 540, aEnd: 600, bStart: 480, bEnd: 510))
  }

  @Test("B becomes a session of the task and A shrinks to its times")
  func bBecomesASession() {
    let library = makeLibrary(reportAtNine, now: 570)

    library.splitTask(
      TaskID("t1"), times: SplitTimes(aStart: 540, aEnd: 560, bStart: 600, bEnd: 630), deferring: false)

    #expect(library.plan.sessions.map(\.start) == [600])
    #expect(library.plan.sessions.map(\.minutes) == [30])
    #expect(library.planSlots.first?.start == 540)
    #expect(library.planSlots.first?.entry.minutes == 20)
    #expect(library.plan.entries.first?.minutes == 50)
  }

  @Test("deferred, B is a new task of its length among the candidates, and A shrinks")
  func deferredBGoesBackToTheCandidates() {
    let library = makeLibrary(reportAtNine, now: 570)

    library.splitTask(
      TaskID("t1"), times: SplitTimes(aStart: 540, aEnd: 570, bStart: 570, bEnd: 600), deferring: true)

    #expect(library.plan.sessions.isEmpty)
    #expect(library.plan.entries.first?.minutes == 30)
    #expect(library.plan.candidates.map(\.task.title) == ["write report"])
    #expect(library.plan.candidates.map(\.minutes) == [30])
  }

  @Test("an A that does not end after it starts changes nothing")
  func aBadAChangesNothing() {
    let library = makeLibrary(reportAtNine, now: 570)

    library.splitTask(
      TaskID("t1"), times: SplitTimes(aStart: 540, aEnd: 540, bStart: 570, bEnd: 600), deferring: false)

    #expect(library.plan.sessions.isEmpty)
    #expect(library.plan.entries.first?.minutes == 60)
  }
}
