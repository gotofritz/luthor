import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let monday = date("2026-10-19")

@MainActor
@Suite("When times are set where a done task already stands")
struct SetTimesAmongDoneTests {
  @Test("the start the task keeps is the one the calendar shows, so Set Times shows it again")
  func theKeptStartIsTheShownOne() {
    let events =
      [
        captured("t1", "write report", lamport: 1), estimated("t1", as: 60, lamport: 3),
        scheduled("t1", on: "2026-10-19", lamport: 4),
      ] + [
        captured("t2", "other", lamport: 10), estimated("t2", as: 30, lamport: 11),
        scheduled("t2", on: "2026-10-19", lamport: 12),
      ]
    let library = LibraryViewModel(
      log: InMemoryEventLog(events), commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
      today: { monday }, now: { 720 })
    library.reload()
    library.show(.today)
    library.setTimes(TaskID("t1"), start: 540, end: 600)
    library.complete(TaskID("t1"))

    library.setTimes(TaskID("t2"), start: 570, end: 600)

    let other = library.plan.entries.first { $0.task.id == TaskID("t2") }
    #expect(library.planSlots.first?.start == 600)
    #expect(other?.start == 600)
  }
}

@MainActor
@Suite("When a task is added to today's plan")
struct AddedToTodayViewModelTests {
  private func library(now: @escaping @Sendable () -> Int) -> LibraryViewModel {
    let events = [
      captured("t1", "short", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
      estimated("t1", as: 5, lamport: 3),
      captured("t2", "long", lamport: 4), prioritized("t2", as: .critical, lamport: 5),
      estimated("t2", as: 60, lamport: 6),
    ]
    let library = LibraryViewModel(
      log: InMemoryEventLog(events), commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
      today: { monday }, now: now)
    library.reload()
    library.show(.today)
    return library
  }

  @Test("it goes to the time now and stays there as the clock moves on")
  func itStaysAtTheTimeItWasAdded() {
    let clock = Clock(765)
    let library = library { clock.minute }

    library.addToPlan(TaskID("t1"))
    clock.minute = 768
    library.reload()

    #expect(library.planSlots.first?.start == 765)
    #expect(library.planSlots.first?.end == 770)
  }

  @Test("with now taken, it goes to the next gap large enough for it")
  func itGoesToTheNextGap() {
    let library = library { 600 }
    library.addToPlan(TaskID("t2"))
    library.setTimes(TaskID("t2"), start: 600, end: 660)
    library.addBlock(title: "lunch", start: 663, end: 700)

    library.addToPlan(TaskID("t1"))

    let short = library.planSlots.first { $0.entry.task.id == TaskID("t1") }
    #expect(short?.start == 700)
  }
}

private final class Clock: @unchecked Sendable {
  var minute: Int
  init(_ minute: Int) { self.minute = minute }
}
