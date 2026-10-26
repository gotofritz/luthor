import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// Home holds the sub-project Kitchen ("replace the tap", then the sub-project Tap with "buy a washer"),
/// then "clear the attic"; Garden is top-level and empty. "buy milk" is in the inbox.
private let homeLog = [
  projectCreated("p1", "Home", kind: .sequential, lamport: 1),
  projectCreated("p2", "Kitchen", under: "p1", lamport: 2),
  projectCreated("p4", "Garden", lamport: 3),
  captured("t1", "replace the tap", lamport: 4),
  captured("t2", "clear the attic", lamport: 5),
  captured("t3", "buy milk", lamport: 6),
  captured("t4", "buy a washer", lamport: 7),
  moved("t1", to: "p2", lamport: 8),
  projectCreated("p3", "Tap", under: "p2", lamport: 9),
  moved("t4", to: "p3", lamport: 10),
  moved("t2", to: "p1", lamport: 11),
]

@MainActor
@Suite("When the inbox is shown")
struct InboxColumnsViewModelTests {
  @Test("the only column lists the top-level projects, in creation order")
  func firstColumnListsTopLevelProjects() {
    let (library, _) = makeInbox(homeLog)

    #expect(library.columns.map(\.parentID) == [nil])
    #expect(library.columns.first?.entries.map(\.id) == ["project-p1", "project-p4"])
    #expect(library.path == [])
  }

  @Test("the list is the inbox, each task a next action")
  func inboxTasksAreNextActions() {
    let (library, _) = makeInbox(homeLog)

    #expect(library.tasks == [item("t3", "buy milk")])
    #expect(library.nextActions == [TaskID("t3")])
  }

  @Test("the flat project list still holds every project, in creation order")
  func projectsStayFlat() {
    let (library, _) = makeInbox(homeLog)

    #expect(library.projects.map(\.title) == ["Home", "Kitchen", "Garden", "Tap"])
  }
}

@MainActor
@Suite("When a sub-project is shown")
struct NestedColumnsViewModelTests {
  @Test("there is a column for each project on its path, listing its sub-projects, then its tasks")
  func columnsFollowThePath() throws {
    let (library, _) = makeInbox(homeLog)
    let kitchen = try #require(library.projects.first { $0.title == "Kitchen" })
    let tap = try #require(library.projects.first { $0.title == "Tap" })

    library.open(.project(TaskID("p2")))

    #expect(library.path == [TaskID("p1"), TaskID("p2")])
    try #require(library.columns.map(\.parentID) == [nil, TaskID("p1"), TaskID("p2")])
    #expect(library.columns[1].entries == [.project(kitchen), .task(item("t2", "clear the attic", in: "p1"))])
    #expect(library.columns[2].entries == [.project(tap), .task(item("t1", "replace the tap", in: "p2"))])
  }

  @Test("the list is its own tasks, without those of its sub-projects")
  func listShowsDirectTasks() {
    let (library, _) = makeInbox(homeLog)

    library.open(.project(TaskID("p2")))

    #expect(library.tasks == [item("t1", "replace the tap", in: "p2")])
  }

  @Test("next actions are the tasks in its columns that the whole tree lets through")
  func nextActionsFollowTheTree() {
    let (library, _) = makeInbox(homeLog)

    library.open(.project(TaskID("p2")))

    // "clear the attic" waits behind Kitchen in sequential Home.
    #expect(library.nextActions == [TaskID("t1")])
  }

  @Test("a sub-project's task is not a next action while an ancestor holds it back")
  func subprojectFollowsItsAncestors() {
    let (library, log) = makeInbox(homeLog)
    log.events += [projectCreated("p5", "Bathroom", under: "p1", lamport: 12)]
    library.reload()

    library.open(.project(TaskID("p5")))
    library.draft = "fix the shower"
    library.submit()

    #expect(library.tasks.map(\.title) == ["fix the shower"])
    #expect(library.nextActions == [])
  }

  @Test("entries have IDs of their own")
  func entryIDsAreDistinct() {
    let (library, _) = makeInbox(homeLog)

    library.open(.project(TaskID("p2")))

    #expect(library.columns.map(\.id) == ["top", "project-p1", "project-p2"])
    #expect(library.columns[2].entries.map(\.id) == ["project-p3", "task-t1"])
  }
}

@MainActor
@Suite("When a project is created in the column of the project shown")
struct SubprojectCreationViewModelTests {
  @Test("it is created inside the shown project")
  func plusButtonCreatesASubproject() {
    let (library, log) = makeInbox(homeLog)
    library.open(.project(TaskID("p4")))

    library.addProject(titled: "Roses", kind: .parallel, under: TaskID("p4"))

    #expect(log.events.last == projectCreated("id-2", "Roses", under: "p4", id: "id-1", on: "2026-10-19", lamport: 12))
    #expect(library.columns.last?.entries.map(\.id) == ["project-id-2"])
  }
}

@MainActor
@Suite("When something is dropped on a column")
struct SidebarDropViewModelTests {
  @Test("a project dropped on another is nested in it")
  func droppedProjectIsNested() {
    let (library, log) = makeInbox(homeLog)

    let accepted = library.drop([LibraryViewModel.dragPayload(for: TaskID("p4"))], on: TaskID("p1"))

    #expect(accepted)
    #expect(log.events.last == nested("p4", under: "p1", id: "id-1", lamport: 12))
    #expect(library.columns.first?.entries.map(\.id) == ["project-p1"])
  }

  @Test("a project dropped on the first column is no longer nested")
  func droppedOnTheTopIsUnnested() {
    let (library, log) = makeInbox(homeLog)

    library.drop([LibraryViewModel.dragPayload(for: TaskID("p2"))], on: nil)

    #expect(log.events.last == nested("p2", under: nil, id: "id-1", lamport: 12))
    #expect(library.columns.first?.entries.map(\.id) == ["project-p1", "project-p2", "project-p4"])
  }

  @Test("a task dropped on a project is filed there")
  func droppedTaskIsFiled() {
    let (library, log) = makeInbox(homeLog)

    library.drop(["t3"], on: TaskID("p4"))

    #expect(log.events.last == moved("t3", to: "p4", id: "id-1", lamport: 12))
    #expect(library.tasks == [])
  }

  @Test("a task dropped on the first column stays where it is")
  func taskDroppedOnTheTopIsIgnored() {
    let (library, log) = makeInbox(homeLog)

    library.drop(["t3"], on: nil)

    #expect(log.events == homeLog)
  }

  @Test("a project dropped on one of its own sub-projects stays where it is")
  func projectDroppedOnItsSubprojectIsIgnored() {
    let (library, log) = makeInbox(homeLog)

    library.drop([LibraryViewModel.dragPayload(for: TaskID("p1"))], on: TaskID("p3"))

    #expect(log.events == homeLog)
    #expect(library.errorMessage == nil)
  }
}

@MainActor
@Suite("When a project is moved to the top from its menu")
struct UnnestViewModelTests {
  @Test("it is top-level")
  func unnestedProjectIsTopLevel() {
    let (library, _) = makeInbox(homeLog)

    library.nest(TaskID("p3"), under: nil)

    #expect(library.columns.first?.entries.map(\.id) == ["project-p1", "project-p4", "project-p3"])
  }
}
