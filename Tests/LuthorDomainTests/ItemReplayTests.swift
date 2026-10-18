import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When an item is given a child")
struct ItemChildReplayTests {
  @Test("a task captured under another makes it a parallel project holding the new task")
  func capturingUnderATaskMakesItAProject() {
    let log = [captured("t1", "plan trip", lamport: 1), captured("t2", "book flights", under: "t1", lamport: 2)]

    let view = LibraryState.replay(log).view(.default)

    #expect(view.projects.map(\.id) == [TaskID("t1")])
    #expect(view.projects.first?.kind == .parallel)
    #expect(view.projects.first?.tasks.map(\.id) == [TaskID("t2")])
    #expect(view.openTasks.map(\.id) == [TaskID("t2")])
  }

  @Test("a task filed under another makes it a project too, and a project nests as it did")
  func filingUnderATaskMakesItAProject() {
    let log = [
      captured("t1", "plan trip", lamport: 1), captured("t2", "book flights", lamport: 1),
      moved("t2", to: "t1", lamport: 2),
    ]

    let view = LibraryState.replay(log).view(.default)

    #expect(view.projects.map(\.id) == [TaskID("t1")])
    #expect(view.projects.first?.children == [.task(item("t2", "book flights", in: "t1"))])
    #expect(view.inbox.isEmpty)
  }

  @Test("an item cannot be filed in its own subtree, and an item that is not open takes no children")
  func cyclesAndClosedParentsAreIgnored() {
    let log = [
      captured("t1", "plan trip", lamport: 1), captured("t2", "book flights", under: "t1", lamport: 1),
      captured("t3", "pay tax", lamport: 1), completed("t3", lamport: 2),
      captured("t4", "call bank", lamport: 1),
      moved("t1", to: "t2", lamport: 3), moved("t4", to: "t3", lamport: 3),
    ]

    let view = LibraryState.replay(log).view(.default)

    #expect(view.projects.map(\.id) == [TaskID("t1")])
    #expect(view.projects.first?.parentID == nil)
    #expect(view.openTasks.map(\.id) == [TaskID("t2"), TaskID("t4")])
    #expect(view.openTasks.last?.parentID == nil)
  }

  @Test("a parent in another view or one that does not exist leaves the item top-level")
  func aParentOfAnotherViewIsIgnored() {
    let log = [
      viewCreated("v1", "Work", lamport: 1), captured("t1", "plan trip", lamport: 1),
      captured("t2", "book flights", view: "v1", under: "t1", lamport: 2),
      captured("t3", "pack", under: "ghost", lamport: 2),
    ]

    let state = LibraryState.replay(log)

    #expect(state.view(ViewID("v1")).openTasks.map(\.parentID) == [nil])
    #expect(state.view(.default).openTasks.map(\.id) == [TaskID("t1"), TaskID("t3")])
    #expect(state.view(.default).projects.isEmpty)
  }

  @Test("an item keeps the kind it was made a project with once its children are gone")
  func anEmptyProjectStaysAProject() {
    let log = [
      captured("t1", "plan trip", lamport: 1), captured("t2", "book flights", under: "t1", lamport: 2),
      completed("t2", lamport: 3),
    ]

    let view = LibraryState.replay(log).view(.default)

    #expect(view.projects.map(\.id) == [TaskID("t1")])
    #expect(view.projects.first?.children.isEmpty == true)
  }
}

@Suite("When a project has what a task has")
struct ItemFieldsReplayTests {
  static let log = [
    projectCreated("p1", "Plan trip", lamport: 1),
    prioritized("p1", as: .important, lamport: 2), estimated("p1", as: 60, lamport: 2),
    dueSet("p1", on: "2026-11-01", lamport: 2), tagCreated("g1", "home", lamport: 2),
    tagged("p1", with: "g1", lamport: 3), scheduled("p1", on: "2026-10-20", lamport: 3),
    noted("p1", "in spring", lamport: 3),
  ]

  @Test("a due date, tags and a day planned are kept for it")
  func aProjectKeepsWhatIsSetOnIt() {
    let state = LibraryState.replay(Self.log)

    #expect(state.dueDate(of: TaskID("p1")) == DueDate(date: date("2026-11-01"), isHard: true))
    #expect(state.tags(of: TaskID("p1")).map(\.name) == ["home"])
    #expect(state.scheduledDate(of: TaskID("p1")) == date("2026-10-20"))
  }

  @Test("it is still listed as a project and never as a task")
  func itIsNotATask() {
    let view = LibraryState.replay(Self.log).view(.default)

    #expect(view.projects.map(\.title) == ["Plan trip"])
    #expect(view.projects.first?.notes == "in spring")
    #expect(view.openTasks.isEmpty)
    #expect(view.inbox.isEmpty)
  }
}

@Suite("When an item is dropped, completed or deleted with others in it")
struct ItemSubtreeReplayTests {
  static let log = [
    captured("t1", "plan trip", lamport: 1), captured("t2", "book flights", under: "t1", lamport: 1),
    captured("t3", "pack", under: "t2", lamport: 1), captured("t4", "water plants", lamport: 1),
  ]

  @Test("completing a task takes everything open in it along, and reopening it brings them back")
  func completingTakesTheSubtree() {
    let done = LibraryState.replay(Self.log + [completed("t1", lamport: 2)]).view(.default)
    let back = LibraryState.replay(Self.log + [completed("t1", lamport: 2), reopened("t1", lamport: 3)])
      .view(.default)

    #expect(done.openTasks.map(\.id) == [TaskID("t4")])
    #expect(done.projects.isEmpty)
    #expect(done.completedProjects.map(\.item.id) == [TaskID("t1"), TaskID("t2")])
    #expect(done.completedTasks.map(\.item.id) == [TaskID("t3")])
    #expect(done.completedTasks.map(\.completedWith) == [TaskID("t1")])
    #expect(back.openTasks.map(\.id) == [TaskID("t3"), TaskID("t4")])
    #expect(back.projects.map(\.id) == [TaskID("t1"), TaskID("t2")])
    #expect(back.completedTasks.isEmpty)
  }

  @Test("dropping a task takes everything open in it along, and reopening it brings them back")
  func droppingTakesTheSubtree() {
    let gone = LibraryState.replay(Self.log + [dropped("t2", lamport: 2)]).view(.default)
    let back = LibraryState.replay(Self.log + [dropped("t2", lamport: 2), reopened("t2", lamport: 3)])
      .view(.default)

    #expect(gone.projects.map(\.id) == [TaskID("t1")])
    #expect(gone.projects.first?.children.isEmpty == true)
    #expect(gone.completedProjects.map(\.isDropped) == [true])
    #expect(gone.completedTasks.map(\.isDropped) == [true])
    #expect(back.projects.map(\.id) == [TaskID("t1"), TaskID("t2")])
    #expect(back.projects.first?.children == [.project(TaskID("t2"))])
    #expect(back.openTasks.map(\.id) == [TaskID("t3"), TaskID("t4")])
  }

  @Test("deleting a task deletes everything in it, open or not")
  func deletingTakesTheSubtree() {
    let view = LibraryState.replay(Self.log + [completed("t3", lamport: 2), taskDeleted("t1", lamport: 3)])
      .view(.default)

    #expect(view.openTasks.map(\.id) == [TaskID("t4")])
    #expect(view.projects.isEmpty)
    #expect(view.completedTasks.isEmpty)
  }

  @Test("an item reopened after its parent was completed is top-level")
  func reopeningUnderAClosedParentIsTopLevel() {
    let log = Self.log + [completed("t3", lamport: 2), completed("t1", lamport: 3), reopened("t3", lamport: 4)]

    let view = LibraryState.replay(log).view(.default)

    #expect(view.openTasks.map(\.id) == [TaskID("t3"), TaskID("t4")])
    #expect(view.openTasks.first?.parentID == nil)
  }
}
