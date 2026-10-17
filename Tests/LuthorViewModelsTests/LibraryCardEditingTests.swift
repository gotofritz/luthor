import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let editLog = [
  projectCreated("p1", "Holiday", kind: .parallel, on: "2026-10-01", lamport: 1),
  captured("t1", "book flights", on: "2026-10-02", lamport: 2), moved("t1", to: "p1", lamport: 3),
  captured("t2", "buy milk", lamport: 4),
]

@MainActor
private func makeLibrary(_ events: [EventEnvelope] = editLog) -> (LibraryViewModel, InMemoryEventLog) {
  let log = InMemoryEventLog(events)
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()), today: { date("2026-10-19") })
  library.reload()
  return (library, log)
}

@MainActor
@Suite("When a task card is shown")
struct TaskCardEditModeTests {
  @Test("it is read-only until Edit is pressed")
  func readOnlyByDefault() {
    let (library, _) = makeLibrary()
    library.selection = TaskID("t2")

    #expect(library.editingCard == nil)
  }

  @Test("Edit puts it into edit mode")
  func editEntersEditMode() {
    let (library, _) = makeLibrary()
    library.selection = TaskID("t2")

    library.editCard(.task(TaskID("t2")))

    #expect(library.editingCard == .task(TaskID("t2")))
  }

  @Test("Cancel leaves edit mode and writes nothing")
  func cancelWritesNothing() {
    let (library, log) = makeLibrary()
    library.selection = TaskID("t2")
    library.editCard(.task(TaskID("t2")))

    library.cancelCardEdit()

    #expect(library.editingCard == nil)
    #expect(log.events == editLog)
  }

  @Test("OK keeps the title, priority, estimate and notes, and leaves edit mode")
  func okKeepsEverything() {
    let (library, _) = makeLibrary()
    library.open(.project(ProjectID("p1")))
    library.selection = TaskID("t1")
    library.editCard(.task(TaskID("t1")))

    library.saveCard(
      ofTask: TaskID("t1"), title: "book trains", priority: .critical, estimate: 15, due: nil, notes: "not planes")

    #expect(library.editingCard == nil)
    #expect(
      library.selectedTask
        == item(
          "t1", "book trains", in: "p1", priority: .critical, estimate: 15, notes: "not planes",
          createdOn: "2026-10-02"))
  }

  @Test("OK with nothing changed writes nothing")
  func okWithoutChangesWritesNothing() {
    let (library, log) = makeLibrary()
    library.selection = TaskID("t2")
    library.editCard(.task(TaskID("t2")))

    library.saveCard(ofTask: TaskID("t2"), title: "buy milk", priority: nil, estimate: nil, due: nil, notes: "")

    #expect(library.editingCard == nil)
    #expect(log.events == editLog)
  }

  @Test("OK with a blank title writes nothing and stays in edit mode")
  func blankTitleStaysInEditMode() {
    let (library, log) = makeLibrary()
    library.selection = TaskID("t2")
    library.editCard(.task(TaskID("t2")))

    library.saveCard(ofTask: TaskID("t2"), title: "  ", priority: .critical, estimate: nil, due: nil, notes: "")

    #expect(library.editingCard == .task(TaskID("t2")))
    #expect(log.events == editLog)
  }

  @Test("selecting another task leaves edit mode")
  func selectingAnotherTaskLeavesEditMode() {
    let (library, _) = makeLibrary()
    library.selection = TaskID("t2")
    library.editCard(.task(TaskID("t2")))

    library.selection = TaskID("t1")

    #expect(library.editingCard == nil)
  }

  @Test("so does showing another place")
  func showingAnotherPlaceLeavesEditMode() {
    let (library, _) = makeLibrary()
    library.selection = TaskID("t2")
    library.editCard(.task(TaskID("t2")))

    library.open(.project(ProjectID("p1")))

    #expect(library.editingCard == nil)
  }

  @Test("the card of a completed task cannot be edited")
  func completedTaskStaysReadOnly() {
    let (library, _) = makeLibrary(editLog + [completed("t2", lamport: 5)])
    library.showCompleted = true
    library.selection = TaskID("t2")

    library.editCard(.task(TaskID("t2")))

    #expect(library.editingCard == nil)
  }

  @Test("a task captured today shows today as the day it was created")
  func capturedTaskHasTheDayItWasCreated() {
    let (library, _) = makeLibrary([])

    library.draft = "call bank"
    library.submit()

    #expect(library.tasks.map(\.createdOn) == [date("2026-10-19")])
  }
}

@MainActor
@Suite("When a project card is shown")
struct ProjectCardEditModeTests {
  @Test("Edit puts it into edit mode and Cancel leaves it, writing nothing")
  func editThenCancel() {
    let (library, log) = makeLibrary()
    library.open(.project(ProjectID("p1")))

    library.editCard(.project(ProjectID("p1")))
    #expect(library.editingCard == .project(ProjectID("p1")))

    library.cancelCardEdit()
    #expect(library.editingCard == nil)
    #expect(log.events == editLog)
  }

  @Test("OK keeps the title, kind and notes, and leaves edit mode")
  func okKeepsEverything() {
    let (library, _) = makeLibrary()
    library.open(.project(ProjectID("p1")))
    library.editCard(.project(ProjectID("p1")))

    library.saveCard(ofProject: ProjectID("p1"), title: "Summer", kind: .sequential, notes: "deadline in June")

    #expect(library.editingCard == nil)
    #expect(library.shownProject?.title == "Summer")
    #expect(library.shownProject?.kind == .sequential)
    #expect(library.shownProject?.notes == "deadline in June")
  }

  @Test("OK with a blank title writes nothing and stays in edit mode")
  func blankTitleStaysInEditMode() {
    let (library, log) = makeLibrary()
    library.open(.project(ProjectID("p1")))
    library.editCard(.project(ProjectID("p1")))

    library.saveCard(ofProject: ProjectID("p1"), title: "", kind: .sequential, notes: "x")

    #expect(library.editingCard == .project(ProjectID("p1")))
    #expect(log.events == editLog)
  }

  @Test("opening another project leaves edit mode")
  func openingAnotherProjectLeavesEditMode() {
    let (library, _) = makeLibrary(editLog + [projectCreated("p2", "Taxes", lamport: 5)])
    library.open(.project(ProjectID("p1")))
    library.editCard(.project(ProjectID("p1")))

    library.open(.project(ProjectID("p2")))

    #expect(library.editingCard == nil)
  }

  @Test("the card of a completed project cannot be edited")
  func completedProjectStaysReadOnly() {
    let (library, _) = makeLibrary(editLog + [projectCompleted("p1", lamport: 5)])
    library.showCompleted = true
    library.open(.project(ProjectID("p1")))

    library.editCard(.project(ProjectID("p1")))

    #expect(library.editingCard == nil)
  }

  @Test("a project created today shows today as the day it was created")
  func createdProjectHasTheDayItWasCreated() {
    let (library, _) = makeLibrary([])
    library.projectDraft = "Taxes"

    library.createProject(kind: .parallel)

    #expect(library.projects.map(\.createdOn) == [date("2026-10-19")])
  }
}
