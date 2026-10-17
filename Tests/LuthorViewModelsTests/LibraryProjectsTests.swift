import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("When a project is created from the sidebar")
struct ProjectCreationViewModelTests {
  @Test("it is listed and the project field is cleared")
  func createProjectListsItAndClearsTheDraft() {
    let (library, log) = makeInbox()
    library.projectDraft = "Move house"

    library.createProject(kind: .sequential)

    #expect(log.events == [projectCreated("id-2", "Move house", kind: .sequential, id: "id-1", lamport: 1)])
    #expect(library.projects == [project("id-2", "Move house", kind: .sequential)])
    #expect(library.projectDraft == "")
  }

  @Test("a blank title creates nothing")
  func blankProjectDraftCreatesNothing() {
    let (library, log) = makeInbox()
    library.projectDraft = "  "

    library.createProject(kind: .parallel)

    #expect(log.events == [])
    #expect(library.errorMessage == nil)
  }

  @Test("a failed write keeps the project field")
  func failedWriteKeepsTheProjectDraft() {
    let (library, log) = makeInbox()
    library.projectDraft = "Move house"
    log.appendFailure = .ioFailure("disk full")

    library.createProject(kind: .parallel)

    #expect(library.projectDraft == "Move house")
    #expect(library.errorMessage == "disk full")
  }
}

@MainActor
@Suite("When the sidebar shows a project")
struct ProjectListViewModelTests {
  static let log = [
    captured("t1", "find a flat", lamport: 1),
    captured("t2", "sign the lease", lamport: 2),
    captured("t3", "buy milk", lamport: 3),
    projectCreated("p1", "Move house", kind: .sequential, lamport: 4),
    moved("t1", to: "p1", lamport: 5),
    moved("t2", to: "p1", lamport: 6),
  ]

  @Test("the list shows the project's tasks in filing order")
  func openingAProjectShowsItsTasks() {
    let (library, _) = makeInbox(Self.log)

    library.open(.project(ProjectID("p1")))

    #expect(library.sidebarSelection == .project(ProjectID("p1")))
    #expect(library.tasks == [item("t1", "find a flat", in: "p1"), item("t2", "sign the lease", in: "p1")])
  }

  @Test("only the project's next actions are marked as such")
  func openingASequentialProjectMarksItsFirstTask() {
    let (library, _) = makeInbox(Self.log)

    library.open(.project(ProjectID("p1")))

    #expect(library.nextActions == [TaskID("t1")])
  }

  @Test("opening it clears the selection")
  func openingAProjectClearsTheSelection() {
    let (library, _) = makeInbox(Self.log)
    library.selection = TaskID("t3")

    library.open(.project(ProjectID("p1")))

    #expect(library.selection == nil)
  }

  @Test("the capture field captures into the project")
  func submitInAProjectCapturesIntoIt() {
    let (library, log) = makeInbox(Self.log)
    library.open(.project(ProjectID("p1")))
    library.draft = "book a van"

    library.submit()

    #expect(
      log.events.suffix(2) == [
        captured("id-2", "book a van", id: "id-1", lamport: 7),
        moved("id-2", to: "p1", id: "id-3", lamport: 8),
      ])
    #expect(library.tasks.map(\.title) == ["find a flat", "sign the lease", "book a van"])
  }

  @Test("going back to the inbox shows the unfiled tasks, all of them next actions")
  func openingTheInboxShowsUnfiledTasks() {
    let (library, _) = makeInbox(Self.log)
    library.open(.project(ProjectID("p1")))

    library.open(.inbox)

    #expect(library.tasks == [item("t3", "buy milk")])
    #expect(library.nextActions == [TaskID("t3")])
  }

  @Test("completing the project there shows the inbox again")
  func completingTheShownProjectShowsTheInbox() {
    let (library, log) = makeInbox(Self.log)
    library.open(.project(ProjectID("p1")))

    library.completeProject(ProjectID("p1"))

    #expect(log.events.last?.payload == .projectCompleted(ProjectCompleted(projectID: ProjectID("p1"))))
    #expect(library.projects == [])
    #expect(library.sidebarSelection == .inbox)
    #expect(library.tasks == [item("t3", "buy milk")])
  }

  @Test("a project completed elsewhere shows the inbox again on reload")
  func projectCompletedElsewhereShowsTheInbox() {
    let (library, log) = makeInbox(Self.log)
    library.open(.project(ProjectID("p1")))

    log.events.append(projectCompleted("p1", device: "cli", lamport: 7))
    library.reload()

    #expect(library.sidebarSelection == .inbox)
  }
}

@MainActor
@Suite("When inbox tasks are filed into a project")
struct FilingViewModelTests {
  static let log = [
    captured("t1", "book flights", lamport: 1),
    captured("t2", "buy milk", lamport: 2),
    captured("t3", "pay rent", lamport: 3),
    projectCreated("p1", "Holiday", lamport: 4),
  ]

  @Test("a filed task leaves the inbox list")
  func filedTaskLeavesTheInboxList() {
    let (library, log) = makeInbox(Self.log)

    library.file(TaskID("t1"), into: ProjectID("p1"))

    #expect(log.events.last == moved("t1", to: "p1", id: "id-1", lamport: 5))
    #expect(library.tasks.map(\.title) == ["buy milk", "pay rent"])
    #expect(library.projects.first?.tasks.map(\.title) == ["book flights"])
  }

  @Test("filing the selected task selects the next one")
  func fileSelectedSelectsTheNextTask() {
    let (library, _) = makeInbox(Self.log)
    library.selection = TaskID("t2")

    library.fileSelected(into: ProjectID("p1"))

    #expect(library.selection == TaskID("t3"))
  }

  @Test("filing without a selection writes nothing")
  func fileSelectedWithoutASelectionDoesNothing() {
    let (library, log) = makeInbox(Self.log)

    library.fileSelected(into: ProjectID("p1"))

    #expect(log.events == Self.log)
  }

  @Test("filing into a project completed elsewhere writes nothing")
  func filingIntoAProjectCompletedElsewhereWritesNothing() {
    let (library, log) = makeInbox(Self.log)
    log.events.append(projectCompleted("p1", device: "cli", lamport: 5))

    library.file(TaskID("t1"), into: ProjectID("p1"))

    #expect(log.events.count == Self.log.count + 1)
    #expect(library.projects == [])
  }
}
