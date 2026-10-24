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

  @Test("stopping it logs the minutes since the start, keeps the start and ends the slot at the time now")
  func stoppingLogsTheMinutes() {
    let clock = Clock(600)
    let library = makeLibrary(planned) { clock.minute }
    library.startNow(TaskID("t1"))
    clock.minute = 645

    library.stopNow(TaskID("t1"))

    #expect(library.plan.entries.first?.start == 600)
    #expect(library.plan.entries.first?.minutes == 45)
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

@MainActor
@Suite("When a task is stopped after its estimated end")
struct RunningOverrunTests {
  @Test("it stays where it started, grows to now and the next task keeps its place if there is room")
  func itGrowsToNow() {
    let events =
      planned + [
        startSet("t1", 600, on: "2026-10-19", lamport: 5),
        captured("t2", "next", lamport: 6), estimated("t2", as: 60, lamport: 7),
        scheduled("t2", on: "2026-10-19", lamport: 8), startSet("t2", 705, on: "2026-10-19", lamport: 9),
      ]
    let clock = Clock(699)
    let library = makeLibrary(events) { clock.minute }

    #expect(library.isRunning(TaskID("t1")))
    library.stopNow(TaskID("t1"))

    let slots = library.planSlots
    #expect(slots.first { $0.entry.task.id == TaskID("t1") }?.start == 600)
    #expect(slots.first { $0.entry.task.id == TaskID("t1") }?.end == 699)
    #expect(slots.first { $0.entry.task.id == TaskID("t2") }?.start == 705)
  }

  @Test("the next task moves along when the new end overlaps it")
  func theNextTaskMovesAlong() {
    let events =
      planned + [
        startSet("t1", 600, on: "2026-10-19", lamport: 5),
        captured("t2", "next", lamport: 6), estimated("t2", as: 60, lamport: 7),
        scheduled("t2", on: "2026-10-19", lamport: 8), startSet("t2", 665, on: "2026-10-19", lamport: 9),
      ]
    let clock = Clock(690)
    let library = makeLibrary(events) { clock.minute }

    library.stopNow(TaskID("t1"))

    let slots = library.planSlots
    #expect(slots.first { $0.entry.task.id == TaskID("t1") }?.end == 690)
    #expect(slots.first { $0.entry.task.id == TaskID("t2") }?.start == 690)
  }
}

@MainActor
@Suite("When a task is dropped on the place of another")
struct DropOnAnotherViewModelTests {
  @Test("the other moves out of the way and keeps its new place")
  func theOtherKeepsItsNewPlace() {
    let events =
      planned + [
        startSet("t1", 600, on: "2026-10-19", lamport: 5),
        captured("t2", "next", lamport: 6), estimated("t2", as: 30, lamport: 7),
        scheduled("t2", on: "2026-10-19", lamport: 8), startSet("t2", 800, on: "2026-10-19", lamport: 9),
      ]
    let library = makeLibrary(events) { 0 }

    library.place(TaskID("t2"), atMinute: 620)

    let slots = library.planSlots
    #expect(slots.first { $0.entry.task.id == TaskID("t2") }?.start == 620)
    #expect(slots.first { $0.entry.task.id == TaskID("t1") }?.start == 650)
    #expect(library.plan.entries.first { $0.task.id == TaskID("t1") }?.start == 650)
  }

  @Test("while it is dragged over, the others show making room")
  func theOthersMakeRoomWhileDragging() {
    let events =
      planned + [
        startSet("t1", 600, on: "2026-10-19", lamport: 5),
        captured("t2", "next", lamport: 6), estimated("t2", as: 30, lamport: 7),
        scheduled("t2", on: "2026-10-19", lamport: 8), startSet("t2", 800, on: "2026-10-19", lamport: 9),
      ]
    let library = makeLibrary(events) { 0 }

    library.dragPreview = (TaskID("t2"), 620)

    #expect(library.planSlots.first { $0.entry.task.id == TaskID("t1") }?.start == 650)
    #expect(library.plan.entries.first { $0.task.id == TaskID("t1") }?.start == 600)
  }
}

@MainActor
@Suite("When a block of untracked time is dropped on a task")
struct DropBlockOnTaskViewModelTests {
  private let events =
    planned + [
      startSet("t1", 600, on: "2026-10-19", lamport: 5),
      blockSet("b1", "Lunch", 720, 780, on: "2026-10-19", lamport: 6),
    ]

  @Test("the task moves out of the way and keeps its new place")
  func theTaskKeepsItsNewPlace() {
    let library = makeLibrary(events) { 0 }

    library.moveBlock(BlockID("b1"), toStart: 630)

    #expect(library.planSlots.first?.start == 690)
    #expect(library.plan.entries.first?.start == 690)
  }

  @Test("while it is dragged over the task, the task shows making room")
  func theTaskMakesRoomWhileDragging() {
    let library = makeLibrary(events) { 0 }

    library.previewBlock(BlockID("b1"), toStart: 630)

    #expect(library.planBlocks.first?.start == 630)
    #expect(library.planSlots.first?.start == 690)
    #expect(library.plan.entries.first?.start == 600)
  }
}

@MainActor
@Suite("When a task is dropped on a block of untracked time")
struct DropTaskOnBlockViewModelTests {
  private let events =
    planned + [
      startSet("t1", 900, on: "2026-10-19", lamport: 5),
      blockSet("b1", "Lunch", 720, 780, on: "2026-10-19", lamport: 6),
    ]

  @Test("the block moves out of the way and keeps its new place")
  func theBlockKeepsItsNewPlace() {
    let library = makeLibrary(events) { 0 }

    library.place(TaskID("t1"), atMinute: 700)

    #expect(library.planBlocks.first?.start == 760)
    #expect(library.plan.blocks.first?.start == 760)
    #expect(library.plan.blocks.first?.end == 820)
  }

  @Test("while the task is dragged over it, the block shows making room")
  func theBlockMakesRoomWhileDragging() {
    let library = makeLibrary(events) { 0 }

    library.dragPreview = (TaskID("t1"), 700)

    #expect(library.planBlocks.first?.start == 760)
    #expect(library.plan.blocks.first?.start == 720)
  }
}

@MainActor
@Suite("When a planned task is given a start and an end")
struct SetTimesViewModelTests {
  @Test("the start is its start and the minutes between are its estimate")
  func theEndSetsTheEstimate() {
    let library = makeLibrary(planned) { 0 }

    library.setTimes(TaskID("t1"), start: 600, end: 645)

    #expect(library.planSlots.first?.start == 600)
    #expect(library.planSlots.first?.end == 645)
    #expect(library.plan.entries.first?.minutes == 45)
  }

  @Test("an end that is not after the start changes nothing")
  func anEndBeforeTheStartChangesNothing() {
    let library = makeLibrary(planned) { 0 }

    library.setTimes(TaskID("t1"), start: 600, end: 600)

    #expect(library.plan.entries.first?.minutes == 60)
    #expect(library.plan.entries.first?.start == nil)
  }
}
