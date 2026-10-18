import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let cardLog = [
  projectCreated("p1", "Holiday", kind: .parallel, lamport: 1),
  captured("t1", "book flights", lamport: 2), moved("t1", to: "p1", lamport: 3),
  captured("t2", "pack", lamport: 4), moved("t2", to: "p1", lamport: 5),
  captured("t3", "buy milk", lamport: 6),
]

@MainActor
@Suite("When a task is selected")
struct TaskCardViewModelTests {
  @Test("nothing is selected by default, so there is no card")
  func noSelectionNoCard() {
    let (library, _) = makeInbox(cardLog)

    #expect(library.selectedTask == nil)
  }

  @Test("the card is the selected task")
  func selectedTaskIsTheCard() {
    let (library, _) = makeInbox(cardLog)

    library.selection = TaskID("t3")

    #expect(library.selectedTask == item("t3", "buy milk"))
  }

  @Test("renaming it shows the new title in the list and on the card")
  func renamingShowsTheNewTitle() {
    let (library, log) = makeInbox(cardLog)
    library.selection = TaskID("t3")

    library.rename(TaskID("t3"), to: "buy oat milk")

    #expect(log.events.last == renamed("t3", to: "buy oat milk", id: "id-1", lamport: 7))
    #expect(library.tasks.map(\.title) == ["buy oat milk"])
    #expect(library.selectedTask?.title == "buy oat milk")
  }

  @Test("a blank title changes nothing")
  func blankTitleChangesNothing() {
    let (library, log) = makeInbox(cardLog)

    library.rename(TaskID("t3"), to: "  ")

    #expect(log.events.count == cardLog.count)
    #expect(library.tasks.map(\.title) == ["buy milk"])
  }

  @Test("notes are set on the card and cleared with a blank text")
  func notesAreSetAndCleared() {
    let (library, _) = makeInbox(cardLog)
    library.selection = TaskID("t3")

    library.setNotes(TaskID("t3"), to: "oat, not soy")
    #expect(library.selectedTask?.notes == "oat, not soy")

    library.setNotes(TaskID("t3"), to: "")
    #expect(library.selectedTask?.notes == nil)
  }

  @Test("a task of a project keeps its notes in the project's list")
  func notesShowInTheProject() {
    let (library, _) = makeInbox(cardLog)
    library.open(.project(TaskID("p1")))

    library.setNotes(TaskID("t1"), to: "window seat")

    #expect(library.tasks.first?.notes == "window seat")
  }
}

@MainActor
@Suite("When a project is shown")
struct ProjectCardViewModelTests {
  @Test("no project is shown in the inbox")
  func inboxShowsNoProject() {
    let (library, _) = makeInbox(cardLog)

    #expect(library.shownProject == nil)
  }

  @Test("the card is the project shown")
  func shownProjectIsTheCard() {
    let (library, _) = makeInbox(cardLog)

    library.open(.project(TaskID("p1")))

    #expect(library.shownProject?.title == "Holiday")
  }

  @Test("a completed project shown is the card too")
  func completedProjectIsTheCard() {
    let (library, _) = makeInbox(cardLog + [projectCompleted("p1", lamport: 7)])
    library.showCompleted = true

    library.open(.project(TaskID("p1")))

    #expect(library.shownProject?.title == "Holiday")
  }

  @Test("renaming it shows in the column and on the card")
  func renamingShowsTheNewTitle() {
    let (library, log) = makeInbox(cardLog)
    library.open(.project(TaskID("p1")))

    library.renameProject(TaskID("p1"), to: "Summer")

    #expect(log.events.last == projectRenamed("p1", to: "Summer", id: "id-1", lamport: 7))
    #expect(library.shownProject?.title == "Summer")
    #expect(library.projects.map(\.title) == ["Summer"])
  }

  @Test("making it sequential holds back its later tasks")
  func sequentialHoldsBackLaterTasks() {
    let (library, _) = makeInbox(cardLog)
    library.open(.project(TaskID("p1")))
    #expect(library.nextActions == [TaskID("t1"), TaskID("t2")])

    library.setKind(of: TaskID("p1"), to: .sequential)

    #expect(library.shownProject?.kind == .sequential)
    #expect(library.nextActions == [TaskID("t1")])
  }

  @Test("notes are set on the card")
  func projectNotes() {
    let (library, _) = makeInbox(cardLog)
    library.open(.project(TaskID("p1")))

    library.setNotes(ofProject: TaskID("p1"), to: "see https://example.com")

    #expect(library.shownProject?.notes == "see https://example.com")
  }
}
