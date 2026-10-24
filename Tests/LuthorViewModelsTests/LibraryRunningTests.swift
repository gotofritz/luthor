import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let monday = date("2026-10-19")

@MainActor
private func makeLibrary(_ events: [EventEnvelope] = [], now: @escaping @Sendable () -> Int) -> LibraryViewModel {
  let library = LibraryViewModel(
    log: InMemoryEventLog(events), commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
    today: { monday }, now: now)
  library.reload()
  return library
}

private let planned = [
  captured("t1", "write report", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
  estimated("t1", as: 60, lamport: 3), scheduled("t1", on: "2026-10-19", lamport: 4),
]

@MainActor
@Suite("When a task is started and stopped now")
struct RunningViewModelTests {
  @Test("starting it gives it the time now as its start, and it is running")
  func startingGivesItTheTimeNow() {
    let library = makeLibrary(planned) { 600 }

    #expect(!library.isRunning(TaskID("t1")))
    library.startNow(TaskID("t1"))

    #expect(library.plan.entries.first?.start == 600)
    #expect(library.isRunning(TaskID("t1")))
  }

  @Test("stopping it logs the minutes since the start, clears the start and ends the run")
  func stoppingLogsTheMinutes() {
    let clock = Clock(600)
    let library = makeLibrary(planned) { clock.minute }
    library.startNow(TaskID("t1"))
    clock.minute = 645

    library.stopNow(TaskID("t1"))

    #expect(library.plan.entries.first?.start == nil)
    #expect(!library.isRunning(TaskID("t1")))
    #expect(library.review.notDone.first?.loggedMinutes == 45)
  }

  @Test("a second run adds to the minutes of the first")
  func aSecondRunAddsToTheFirst() {
    let clock = Clock(600)
    let library = makeLibrary(planned) { clock.minute }
    library.startNow(TaskID("t1"))
    clock.minute = 630
    library.stopNow(TaskID("t1"))
    clock.minute = 700
    library.startNow(TaskID("t1"))
    clock.minute = 710

    library.stopNow(TaskID("t1"))

    #expect(library.review.notDone.first?.loggedMinutes == 40)
  }

  @Test("it is not running before its start time, nor on another day")
  func itIsNotRunningBeforeItsStart() {
    let library = makeLibrary(planned + [startSet("t1", 900, on: "2026-10-19", lamport: 5)]) { 600 }

    #expect(!library.isRunning(TaskID("t1")))
  }

  @Test("another day cannot be started")
  func anotherDayCannotBeStarted() {
    let library = makeLibrary(planned) { 600 }
    library.showDay(date("2026-10-20"))

    library.startNow(TaskID("t1"))
    library.showDay(monday)

    #expect(library.plan.entries.first?.start == nil)
  }
}

/// A clock a test can move.
private final class Clock: @unchecked Sendable {
  var minute: Int
  init(_ minute: Int) { self.minute = minute }
}

@MainActor
@Suite("When the review of a day is closed")
struct ReviewPrefillViewModelTests {
  @Test("a done task with an estimate and no time logged is logged at its estimate")
  func aDoneTaskIsLoggedAtItsEstimate() {
    let library = makeLibrary(planned + [completed("t1", lamport: 5)]) { 600 }

    library.reviewDay(note: "")

    #expect(library.review.done.first?.loggedMinutes == 60)
  }

  @Test("time already logged is left alone")
  func timeAlreadyLoggedIsLeftAlone() {
    let library = makeLibrary(planned + [completed("t1", lamport: 5)]) { 600 }
    library.logTime(TaskID("t1"), minutes: 45)

    library.reviewDay(note: "")

    #expect(library.review.done.first?.loggedMinutes == 45)
  }
}
