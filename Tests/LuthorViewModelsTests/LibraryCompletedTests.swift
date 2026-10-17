import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// Holiday holds "book flights" (open), "pack" (completed on its own) and the sub-project Packing with
/// "passport"; Garden is top-level and completed with nothing in it. "buy milk" is completed, loose.
private let completedLog = [
  projectCreated("p1", "Holiday", lamport: 1),
  projectCreated("p2", "Packing", under: "p1", lamport: 2),
  projectCreated("p3", "Garden", lamport: 3),
  captured("t1", "book flights", lamport: 4), moved("t1", to: "p1", lamport: 5),
  captured("t2", "pack", lamport: 6), moved("t2", to: "p1", lamport: 7), completed("t2", lamport: 8),
  captured("t3", "passport", lamport: 9), moved("t3", to: "p2", lamport: 10),
  captured("t4", "buy milk", lamport: 11), completed("t4", lamport: 12),
  projectCompleted("p3", lamport: 13),
]

@MainActor
@Suite("When completed items are hidden")
struct CompletedHiddenViewModelTests {
  @Test("they are hidden by default")
  func completedItemsAreHiddenByDefault() {
    let (library, _) = makeInbox(completedLog)

    #expect(library.showCompleted == false)
    #expect(library.columns.first?.entries.map(\.id) == ["project-p1"])
    #expect(library.tasks.isEmpty)
    #expect(library.completedTaskIDs.isEmpty)
    #expect(library.completedProjectIDs.isEmpty)
  }
}

@MainActor
@Suite("When completed items are shown")
struct CompletedShownViewModelTests {
  @Test("a completed top-level project follows the active ones")
  func completedProjectsFollowTheActiveOnes() {
    let (library, _) = makeInbox(completedLog)

    library.showCompleted = true

    #expect(library.columns.first?.entries.map(\.id) == ["project-p1", "project-p3"])
    #expect(library.completedProjectIDs == [ProjectID("p3")])
    #expect(library.reopenableProjectIDs == [ProjectID("p3")])
  }

  @Test("a completed loose task follows the inbox")
  func completedTasksFollowTheInbox() {
    let (library, _) = makeInbox(completedLog)

    library.showCompleted = true

    #expect(library.tasks == [item("t4", "buy milk")])
    #expect(library.completedTaskIDs == [TaskID("t4")])
    #expect(library.reopenableTaskIDs == [TaskID("t4")])
    #expect(library.nextActions.isEmpty)
  }

  @Test("a project's column lists its completed tasks after its open children")
  func projectColumnListsCompletedTasksLast() {
    let (library, _) = makeInbox(completedLog)
    library.showCompleted = true

    library.open(.project(ProjectID("p1")))

    #expect(library.columns.last?.entries.map(\.id) == ["project-p2", "task-t1", "task-t2"])
    #expect(library.tasks.map(\.title) == ["book flights", "pack"])
    #expect(library.completedTaskIDs == [TaskID("t2")])
  }

  @Test("a completed project can be opened, and shows what was completed with it")
  func completedProjectCanBeOpened() {
    let log = completedLog + [projectCompleted("p1", lamport: 14)]
    let (library, _) = makeInbox(log)
    library.showCompleted = true

    library.open(.project(ProjectID("p1")))

    #expect(library.path == [ProjectID("p1")])
    #expect(library.columns.last?.entries.map(\.id) == ["project-p2", "task-t2", "task-t1"])
    #expect(library.completedTaskIDs == [TaskID("t2"), TaskID("t1")])
    #expect(library.reopenableTaskIDs == [TaskID("t2")])
    #expect(library.reopenableProjectIDs == [ProjectID("p1"), ProjectID("p3")])
  }

  @Test("the priorities list their completed tasks too")
  func prioritiesListCompletedTasks() {
    let log = [
      captured("t1", "buy milk", lamport: 1), prioritized("t1", as: .important, lamport: 2),
      completed("t1", lamport: 3), captured("t2", "call bank", lamport: 4),
      prioritized("t2", as: .important, lamport: 5),
    ]
    let (library, _) = makeInbox(log)
    library.showCompleted = true
    library.show(.priorities)

    library.togglePriority(.important)

    #expect(library.tasks.map(\.title) == ["call bank", "buy milk"])
  }

  @Test("hiding them again takes them off the lists")
  func hidingThemAgain() {
    let (library, _) = makeInbox(completedLog)
    library.showCompleted = true

    library.showCompleted = false

    #expect(library.columns.first?.entries.map(\.id) == ["project-p1"])
    #expect(library.tasks.isEmpty)
  }

  @Test("completing the project shown keeps it shown, as completed")
  func completingTheShownProjectKeepsItShown() {
    let (library, _) = makeInbox(completedLog)
    library.showCompleted = true
    library.open(.project(ProjectID("p1")))

    library.completeProject(ProjectID("p1"))

    #expect(library.path == [ProjectID("p1")])
    #expect(library.completedProjectIDs.contains(ProjectID("p1")))
  }
}

@MainActor
@Suite("When a completed item is reopened")
struct ReopenViewModelTests {
  @Test("a task is open again and no longer completed")
  func reopenedTaskIsOpen() {
    let (library, log) = makeInbox(completedLog)
    library.showCompleted = true

    library.reopen(TaskID("t4"))

    #expect(log.events.last == reopened("t4", id: "id-1", lamport: 14))
    #expect(library.completedTaskIDs.isEmpty)
    #expect(library.tasks == [item("t4", "buy milk")])
    #expect(library.nextActions == [TaskID("t4")])
  }

  @Test("a project is active again with what was completed along with it")
  func reopenedProjectIsActive() {
    let (library, log) = makeInbox(completedLog)
    library.showCompleted = true

    library.reopenProject(ProjectID("p3"))

    #expect(log.events.last == projectReopened("p3", id: "id-1", lamport: 14))
    #expect(library.completedProjectIDs.isEmpty)
    #expect(library.columns.first?.entries.map(\.id) == ["project-p1", "project-p3"])
  }

  @Test("a task that cannot be reopened writes nothing")
  func cascadedTaskIsNotReopened() {
    let (library, log) = makeInbox(completedLog + [projectCompleted("p1", lamport: 14)])
    let before = log.events.count

    library.reopen(TaskID("t1"))

    #expect(log.events.count == before)
  }
}
