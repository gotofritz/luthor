import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When a task is completed")
struct CompletedTaskReplayTests {
  static let log = [
    captured("t1", "buy milk", lamport: 1),
    captured("t2", "call bank", lamport: 2),
    completed("t1", lamport: 3),
  ]

  @Test("it is kept as completed, apart from the open tasks")
  func completedTaskIsKept() {
    let view = LibraryState.replay(Self.log).view(.default)

    #expect(view.completedTasks.map(\.item) == [item("t1", "buy milk")])
    #expect(view.openTasks == [item("t2", "call bank")])
  }

  @Test("it was completed by itself, so it can be reopened")
  func completedTaskIsReopenable() {
    let view = LibraryState.replay(Self.log).view(.default)

    #expect(view.completedTasks.map(\.isReopenable) == [true])
  }

  @Test("completed tasks are listed in the order they were completed")
  func completedTasksKeepCompletionOrder() {
    let log = Self.log + [completed("t2", lamport: 4)]

    #expect(LibraryState.replay(log).view(.default).completedTasks.map(\.item.id.rawValue) == ["t1", "t2"])
  }

  @Test("it stays in its own view")
  func completedTaskStaysInItsView() {
    let log = [
      viewCreated("v2", "Work", lamport: 1), captured("t1", "report", view: "v2", lamport: 2), completed("t1"),
    ]
    let state = LibraryState.replay(log)

    #expect(state.view(.default).completedTasks.isEmpty)
    #expect(state.view(ViewID("v2")).completedTasks.map(\.item.title) == ["report"])
  }

  @Test("it keeps the priority and estimate it had")
  func completedTaskKeepsItsDetails() {
    let log = [
      captured("t1", "buy milk", lamport: 1), prioritized("t1", as: .important, lamport: 2),
      estimated("t1", as: 15, lamport: 3), completed("t1", lamport: 4),
    ]

    #expect(
      LibraryState.replay(log).view(.default).completedTasks.map(\.item)
        == [item("t1", "buy milk", priority: .important, estimate: 15)])
  }

  @Test("completing it again changes nothing")
  func completingTwiceKeepsOneCopy() {
    let log = Self.log + [completed("t1", id: "again", lamport: 4)]

    #expect(LibraryState.replay(log).view(.default).completedTasks.count == 1)
  }

  @Test("a dropped task is kept as dropped, not as completed")
  func droppedTaskIsKeptAsDropped() {
    let log = [captured("t1", "buy milk", lamport: 1), dropped("t1", lamport: 2)]
    let view = LibraryState.replay(log).view(.default)

    #expect(view.openTasks.isEmpty)
    #expect(view.completedTasks.map(\.item.id) == [TaskID("t1")])
    #expect(view.completedTasks.map(\.isDropped) == [true])
  }

  @Test("a dropped task can be reopened")
  func droppedTaskCanBeReopened() {
    let log = [captured("t1", "buy milk", lamport: 1), dropped("t1", lamport: 2), reopened("t1", lamport: 3)]
    let view = LibraryState.replay(log).view(.default)

    #expect(view.openTasks.map(\.id) == [TaskID("t1")])
    #expect(view.completedTasks.isEmpty)
  }
}

@Suite("When a completed task is reopened")
struct TaskReopenReplayTests {
  @Test("it is open again, in the inbox")
  func reopenedTaskIsOpen() {
    let log = [captured("t1", "buy milk", lamport: 1), completed("t1", lamport: 2), reopened("t1", lamport: 3)]
    let view = LibraryState.replay(log).view(.default)

    #expect(view.inbox == [item("t1", "buy milk")])
    #expect(view.completedTasks.isEmpty)
  }

  @Test("it takes its place by capture order, not at the end")
  func reopenedTaskKeepsCaptureOrder() {
    let log = [
      captured("t1", "first", lamport: 1), captured("t2", "second", lamport: 2),
      completed("t1", lamport: 3), reopened("t1", lamport: 4),
    ]

    #expect(LibraryState.replay(log).view(.default).openTasks.map(\.title) == ["first", "second"])
  }

  @Test("it goes back into its project while that is active")
  func reopenedTaskReturnsToItsProject() {
    let log = [
      projectCreated("p1", "Holiday", lamport: 1), captured("t1", "book flights", lamport: 2),
      moved("t1", to: "p1", lamport: 3), completed("t1", lamport: 4), reopened("t1", lamport: 5),
    ]

    #expect(
      LibraryState.replay(log).view(.default).projects == [
        project("p1", "Holiday", tasks: [item("t1", "book flights", in: "p1")])
      ])
  }

  @Test("it comes back loose when its project is completed")
  func reopenedTaskOfACompletedProjectIsLoose() {
    let log = [
      projectCreated("p1", "Holiday", lamport: 1), captured("t1", "book flights", lamport: 2),
      moved("t1", to: "p1", lamport: 3), completed("t1", lamport: 4),
      projectCompleted("p1", lamport: 5), reopened("t1", lamport: 6),
    ]

    #expect(LibraryState.replay(log).view(.default).openTasks == [item("t1", "book flights")])
  }

  @Test("a task completed along with its project cannot be reopened by itself")
  func cascadedTaskIsNotReopenable() {
    let log = [
      projectCreated("p1", "Holiday", lamport: 1), captured("t1", "book flights", lamport: 2),
      moved("t1", to: "p1", lamport: 3), projectCompleted("p1", lamport: 4), reopened("t1", lamport: 5),
    ]
    let view = LibraryState.replay(log).view(.default)

    #expect(view.openTasks.isEmpty)
    #expect(view.completedTasks.map(\.isReopenable) == [false])
  }

  @Test("a task that is not completed is ignored")
  func reopeningAnOpenTaskChangesNothing() {
    let log = [captured("t1", "buy milk", lamport: 1), reopened("t1", lamport: 2)]

    #expect(LibraryState.replay(log).view(.default).openTasks == [item("t1", "buy milk")])
  }
}

@Suite("When a project is completed")
struct CompletedProjectReplayTests {
  static let log = [
    projectCreated("p1", "Holiday", lamport: 1),
    projectCreated("p2", "Packing", under: "p1", lamport: 2),
    captured("t1", "book flights", lamport: 3), moved("t1", to: "p1", lamport: 4),
    captured("t2", "passport", lamport: 5), moved("t2", to: "p2", lamport: 6),
    captured("t3", "tickets", lamport: 7), moved("t3", to: "p1", lamport: 8), completed("t3", lamport: 9),
    projectCompleted("p1", lamport: 10),
  ]

  @Test("it is kept as completed, with its sub-projects")
  func completedProjectIsKept() {
    let view = LibraryState.replay(Self.log).view(.default)

    #expect(view.projects.isEmpty)
    #expect(view.completedProjects.map(\.item.id.rawValue) == ["p1", "p2"])
  }

  @Test("only the project completed itself can be reopened")
  func onlyTheRootIsReopenable() {
    let view = LibraryState.replay(Self.log).view(.default)

    #expect(view.completedProjects.map(\.isReopenable) == [true, false])
  }

  @Test("the tasks that were open are kept with it")
  func openTasksAreCompletedWithIt() {
    let view = LibraryState.replay(Self.log).view(.default)

    #expect(view.completedTasks.map(\.item.id.rawValue) == ["t3", "t1", "t2"])
    #expect(view.completedTasks.map(\.isReopenable) == [true, false, false])
  }

  @Test("it remembers where it was nested")
  func completedSubprojectKeepsItsParent() {
    let log = [
      projectCreated("p1", "Holiday", lamport: 1), projectCreated("p2", "Packing", under: "p1", lamport: 2),
      projectCompleted("p2", lamport: 3),
    ]
    let view = LibraryState.replay(log).view(.default)

    #expect(view.completedProjects.map(\.item.parentID) == [TaskID("p1")])
    #expect(view.projects == [project("p1", "Holiday")])
  }
}

@Suite("When a completed project is reopened")
struct ProjectReopenReplayTests {
  @Test("it comes back with the tasks and sub-projects that were completed along with it")
  func reopenRestoresTheCascade() {
    let log = CompletedProjectReplayTests.log + [projectReopened("p1", lamport: 11)]
    let view = LibraryState.replay(log).view(.default)

    #expect(
      view.projects == [
        project(
          "p1", "Holiday", children: [sub("p2"), .task(item("t1", "book flights", in: "p1"))]),
        project("p2", "Packing", under: "p1", tasks: [item("t2", "passport", in: "p2")]),
      ])
    #expect(view.completedProjects.isEmpty)
  }

  @Test("a task completed on its own stays completed")
  func individuallyCompletedTasksStayCompleted() {
    let log = CompletedProjectReplayTests.log + [projectReopened("p1", lamport: 11)]

    #expect(LibraryState.replay(log).view(.default).completedTasks.map(\.item.id.rawValue) == ["t3"])
  }

  @Test("a sub-project goes back into its parent while that is active")
  func reopenedSubprojectRejoinsItsParent() {
    let log = [
      projectCreated("p1", "Holiday", lamport: 1), projectCreated("p2", "Packing", under: "p1", lamport: 2),
      projectCompleted("p2", lamport: 3), projectReopened("p2", lamport: 4),
    ]

    #expect(
      LibraryState.replay(log).view(.default).projects == [
        project("p1", "Holiday", children: [sub("p2")]), project("p2", "Packing", under: "p1"),
      ])
  }

  @Test("a sub-project comes back top-level when its parent is completed")
  func reopenedSubprojectOfACompletedParentIsTopLevel() {
    let log = [
      projectCreated("p1", "Holiday", lamport: 1), projectCreated("p2", "Packing", under: "p1", lamport: 2),
      projectCompleted("p2", lamport: 3), projectCompleted("p1", lamport: 4), projectReopened("p2", lamport: 5),
    ]
    let view = LibraryState.replay(log).view(.default)

    #expect(view.projects == [project("p2", "Packing")])
    #expect(view.completedProjects.map(\.item.id.rawValue) == ["p1"])
  }

  @Test("the tasks of a reopened project keep their capture order among the open tasks")
  func reopenedTasksKeepCaptureOrder() {
    let log = [
      projectCreated("p1", "Holiday", lamport: 1), captured("t1", "first", lamport: 2),
      moved("t1", to: "p1", lamport: 3), captured("t2", "second", lamport: 4), projectCompleted("p1", lamport: 5),
      projectReopened("p1", lamport: 6),
    ]

    #expect(LibraryState.replay(log).view(.default).openTasks.map(\.title) == ["first", "second"])
  }

  @Test("a project that is not completed is ignored")
  func reopeningAnActiveProjectChangesNothing() {
    let log = [projectCreated("p1", "Holiday", lamport: 1), projectReopened("p1", lamport: 2)]

    #expect(LibraryState.replay(log).view(.default).projects == [project("p1", "Holiday")])
  }

  @Test("a project completed along with another cannot be reopened by itself")
  func cascadedProjectIsIgnored() {
    let log = CompletedProjectReplayTests.log + [projectReopened("p2", lamport: 11)]

    #expect(LibraryState.replay(log).view(.default).projects.isEmpty)
  }
}
