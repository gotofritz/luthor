import LuthorDomain
import LuthorTestSupport
import LuthorViewModels
import Testing

/// Garden holds one task.
private let gardenLog = [
  projectCreated("p1", "Garden", lamport: 1),
  captured("t1", "mow the lawn", under: "p1", lamport: 2),
]

@MainActor
@Suite("When a new task is kept with a scheduled day")
struct NewItemScheduledViewModelTests {
  @Test("it is planned for that day")
  func itIsPlannedForThatDay() throws {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)

    library.saveNewItem(
      TaskCardDraft(
        title: "water roses", priority: nil, estimate: nil, due: nil, notes: "", scheduled: date("2026-10-21")))

    let created = try #require(library.selection)
    #expect(library.scheduledDate(of: created) == date("2026-10-21"))
  }

  @Test("without one it is planned for none")
  func withoutOneItIsPlannedForNone() throws {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)

    library.saveNewItem(TaskCardDraft(title: "water roses", priority: nil, estimate: nil, due: nil, notes: ""))

    let created = try #require(library.selection)
    #expect(library.scheduledDate(of: created) == nil)
  }
}
