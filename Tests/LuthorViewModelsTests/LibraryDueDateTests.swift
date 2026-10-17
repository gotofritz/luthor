import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let monday = date("2026-10-19")

@MainActor
private func makeLibrary(_ events: [EventEnvelope] = []) -> (LibraryViewModel, InMemoryEventLog) {
  let log = InMemoryEventLog(events)
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()), today: { monday })
  library.reload()
  return (library, log)
}

private let oneTask = [captured("t1", "pay tax", lamport: 1)]

@MainActor
@Suite("When a due date is set in the window")
struct LibraryDueDateTests {
  @Test("it is written as a hard deadline or a target date, and the task reads it back")
  func itIsWrittenAndRead() {
    let (library, log) = makeLibrary(oneTask)

    library.setDue(TaskID("t1"), to: date("2026-10-23"), isHard: false)

    #expect(log.events.last == dueSet("t1", on: "2026-10-23", hard: false, id: "id-1", lamport: 2))
    #expect(library.dueDate(of: TaskID("t1")) == DueDate(date: date("2026-10-23"), isHard: false))
  }

  @Test("a task that is not open changes nothing")
  func aTaskThatIsNotOpenChangesNothing() {
    let (library, log) = makeLibrary(oneTask)

    library.setDue(TaskID("t9"), to: date("2026-10-23"), isHard: true)

    #expect(log.events == oneTask)
    #expect(library.dueDate(of: TaskID("t9")) == nil)
  }

  @Test("OK on a card keeps a due date and clears it, and writes nothing when it is unchanged")
  func okOnACardKeepsAndClearsADueDate() {
    let (library, log) = makeLibrary(oneTask)
    let due = DueDate(date: date("2026-10-23"), isHard: true)

    library.editCard(.task(TaskID("t1")))
    library.saveCard(
      ofTask: TaskID("t1"), TaskCardDraft(title: "pay tax", priority: nil, estimate: nil, due: due, notes: ""))
    #expect(library.dueDate(of: TaskID("t1")) == due)
    #expect(library.editingCard == nil)

    let written = log.events.count
    library.editCard(.task(TaskID("t1")))
    library.saveCard(
      ofTask: TaskID("t1"), TaskCardDraft(title: "pay tax", priority: nil, estimate: nil, due: due, notes: ""))
    #expect(log.events.count == written)

    library.editCard(.task(TaskID("t1")))
    library.saveCard(
      ofTask: TaskID("t1"), TaskCardDraft(title: "pay tax", priority: nil, estimate: nil, due: nil, notes: ""))
    #expect(library.dueDate(of: TaskID("t1")) == nil)
  }

  @Test("a hard deadline that is due puts the task first among Today's candidates")
  func aDueHardDeadlinePutsTheTaskFirst() {
    let (library, _) = makeLibrary(
      oneTask + [
        prioritized("t1", as: .important, lamport: 2), captured("t2", "write report", lamport: 3),
        prioritized("t2", as: .important, lamport: 4),
      ])
    library.show(.today)
    #expect(library.tasks.map(\.title) == ["pay tax", "write report"])

    library.setDue(TaskID("t2"), to: monday, isHard: true)

    #expect(library.tasks.map(\.title) == ["write report", "pay tax"])
  }
}
