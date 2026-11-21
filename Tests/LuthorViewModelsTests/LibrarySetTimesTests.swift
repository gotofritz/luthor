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
