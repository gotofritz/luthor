import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// Holiday holds "book flights"; "buy milk" is loose in the inbox. The lamport counter is 4.
private let holidayLog = [
  projectCreated("p1", "Holiday", lamport: 1),
  captured("t1", "book flights", lamport: 2), moved("t1", to: "p1", lamport: 3),
  captured("t2", "buy milk", lamport: 4),
]

@MainActor
@Suite("When a task is duplicated in the window")
struct DuplicateViewModelTests {
  @Test("the copy is written, listed beside the original and selected")
  func theCopyIsListedAndSelected() {
    let (library, log) = makeInbox(holidayLog)
    library.open(.project(ProjectID("p1")))

    library.duplicate(TaskID("t1"))

    #expect(log.events.last == duplicated("t1", as: "id-2", on: "2026-10-19", id: "id-1", lamport: 5))
    #expect(library.tasks.map(\.title) == ["book flights", "book flights"])
    #expect(library.selection == TaskID("id-2"))
  }

  @Test("a task that is no longer open writes nothing")
  func aTaskThatIsNoLongerOpenWritesNothing() {
    let (library, log) = makeInbox(holidayLog + [completed("t2", lamport: 5)])

    library.duplicate(TaskID("t2"))

    #expect(log.events.count == holidayLog.count + 1)
  }
}

@MainActor
@Suite("When a task is deleted in the window")
struct DeleteTaskViewModelTests {
  @Test("an open task leaves the list and the selection")
  func anOpenTaskLeavesTheList() {
    let (library, log) = makeInbox(holidayLog)
    library.selection = TaskID("t2")

    library.deleteTask(TaskID("t2"))

    #expect(log.events.last == taskDeleted("t2", id: "id-1", lamport: 5))
    #expect(library.tasks.isEmpty)
    #expect(library.selection == nil)
  }

  @Test("a completed task leaves the list of completed items")
  func aCompletedTaskLeavesTheCompletedItems() {
    let (library, _) = makeInbox(holidayLog + [completed("t2", lamport: 5)])
    library.showCompleted = true
    #expect(library.completedTaskIDs == [TaskID("t2")])

    library.deleteTask(TaskID("t2"))

    #expect(library.completedTaskIDs.isEmpty)
    #expect(library.tasks.isEmpty)
  }
}

@MainActor
@Suite("When a project is deleted in the window")
struct DeleteProjectViewModelTests {
  @Test("it leaves the first column and, if it was shown, the inbox is shown again")
  func theShownProjectLeavesTheColumns() {
    let (library, log) = makeInbox(holidayLog)
    library.open(.project(ProjectID("p1")))

    library.deleteProject(ProjectID("p1"))

    #expect(log.events.last == projectDeleted("p1", id: "id-1", lamport: 5))
    #expect(library.columns.first?.entries.isEmpty == true)
    #expect(library.shownProject == nil)
    #expect(library.sidebarSelection == .inbox)
    #expect(library.tasks.map(\.id) == [TaskID("t2")])
  }

  @Test("a completed project is deleted from the list of completed items")
  func aCompletedProjectIsDeleted() {
    let (library, _) = makeInbox(holidayLog + [projectCompleted("p1", lamport: 5)])
    library.showCompleted = true
    #expect(library.completedProjectIDs == [ProjectID("p1")])

    library.deleteProject(ProjectID("p1"))

    #expect(library.completedProjectIDs.isEmpty)
    #expect(library.completedTaskIDs.isEmpty)
  }
}

@MainActor
@Suite("When tasks are added to a task in the window")
struct AddTasksViewModelTests {
  @Test("the task becomes a project, which is shown, ready to capture into")
  func theTaskBecomesTheProjectShown() {
    let (library, log) = makeInbox(holidayLog)
    library.selection = TaskID("t2")

    library.addTasks(to: TaskID("t2"))

    #expect(log.events.last == promoted("t2", to: "id-2", id: "id-1", lamport: 5))
    #expect(library.section == .projects)
    #expect(library.shownProject?.id == ProjectID("id-2"))
    #expect(library.shownProject?.title == "buy milk")
    #expect(library.tasks.isEmpty)
    #expect(library.selection == nil)
  }

  @Test("a task captured next is filed in it")
  func aTaskCapturedNextIsFiledInIt() {
    let (library, _) = makeInbox(holidayLog)
    library.addTasks(to: TaskID("t2"))

    library.draft = "oat milk"
    library.submit()

    #expect(library.tasks.map(\.title) == ["oat milk"])
    #expect(library.shownProject?.tasks.map(\.title) == ["oat milk"])
  }

  @Test("a task filed in a project becomes a sub-project, and the path shows both")
  func aFiledTaskBecomesASubproject() {
    let (library, _) = makeInbox(holidayLog)

    library.addTasks(to: TaskID("t1"))

    #expect(library.path == [ProjectID("p1"), ProjectID("id-2")])
    #expect(library.shownProject?.parentID == ProjectID("p1"))
  }

  @Test("a task that is no longer open writes nothing")
  func aTaskThatIsNoLongerOpenWritesNothing() {
    let (library, log) = makeInbox(holidayLog + [completed("t2", lamport: 5)])

    library.addTasks(to: TaskID("t2"))

    #expect(log.events.count == holidayLog.count + 1)
    #expect(library.shownProject == nil)
  }
}
