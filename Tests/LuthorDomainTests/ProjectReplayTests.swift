import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When a project is created")
struct ProjectCreationReplayTests {
  @Test("it is listed, empty, after the projects created before it")
  func createdProjectsAreListedInCreationOrder() {
    let state = LibraryState.replay([
      projectCreated("p1", "Holiday", lamport: 1),
      projectCreated("p2", "Move house", kind: .sequential, lamport: 2),
    ])

    #expect(state.projects == [project("p1", "Holiday"), project("p2", "Move house", kind: .sequential)])
  }

  @Test("creating it again under the same ID changes nothing")
  func recreatingAProjectIsIgnored() {
    let state = LibraryState.replay([
      projectCreated("p1", "Holiday", id: "e1", lamport: 1),
      projectCreated("p1", "Other", id: "e2", lamport: 2),
    ])

    #expect(state.projects == [project("p1", "Holiday")])
  }
}

@Suite("When an inbox task is filed into a project")
struct TaskFilingReplayTests {
  static let log = [
    captured("t1", "book flights", lamport: 1),
    captured("t2", "buy milk", lamport: 2),
    projectCreated("p1", "Holiday", lamport: 3),
    moved("t1", to: "p1", lamport: 4),
  ]

  @Test("it leaves the inbox")
  func filedTaskLeavesTheInbox() {
    #expect(LibraryState.replay(Self.log).inbox == [item("t2", "buy milk")])
  }

  @Test("it shows in the project")
  func filedTaskShowsInTheProject() {
    #expect(
      LibraryState.replay(Self.log).projects == [
        project("p1", "Holiday", tasks: [item("t1", "book flights", in: "p1")])
      ])
  }

  @Test("it stays open")
  func filedTaskStaysOpen() {
    #expect(
      LibraryState.replay(Self.log).openTasks == [item("t1", "book flights", in: "p1"), item("t2", "buy milk")])
  }

  @Test("it joins the end of the project's tasks")
  func filedTasksKeepTheirFilingOrder() {
    let state = LibraryState.replay(Self.log + [moved("t2", to: "p1", lamport: 5)])

    #expect(state.projects.first?.tasks.map(\.title) == ["book flights", "buy milk"])
  }

  @Test("filing it into another project moves it there")
  func refilingMovesTheTask() {
    let refiled = [projectCreated("p2", "Errands", lamport: 5), moved("t1", to: "p2", lamport: 6)]

    let state = LibraryState.replay(Self.log + refiled)

    #expect(
      state.projects == [
        project("p1", "Holiday"),
        project("p2", "Errands", tasks: [item("t1", "book flights", in: "p2")]),
      ])
  }

  @Test("filing it again into the same project keeps its place")
  func refilingIntoTheSameProjectChangesNothing() {
    let refiled = [moved("t2", to: "p1", lamport: 5), moved("t1", to: "p1", id: "again", lamport: 6)]

    let state = LibraryState.replay(Self.log + refiled)

    #expect(state.projects.first?.tasks.map(\.title) == ["book flights", "buy milk"])
  }

  @Test("completing it removes it from the project")
  func completingAFiledTaskRemovesIt() {
    let state = LibraryState.replay(Self.log + [completed("t1", lamport: 5)])

    #expect(state.projects == [project("p1", "Holiday")])
    #expect(state.openTasks == [item("t2", "buy milk")])
  }
}

@Suite("When a task cannot be filed")
struct IgnoredFilingReplayTests {
  @Test("filing into a project that does not exist leaves the task in the inbox")
  func filingIntoAnUnknownProjectIsIgnored() {
    let state = LibraryState.replay([captured("t1", "book flights", lamport: 1), moved("t1", to: "p9", lamport: 2)])

    #expect(state.inbox == [item("t1", "book flights")])
  }

  @Test("filing a task that is not open changes no project")
  func filingAClosedTaskIsIgnored() {
    let state = LibraryState.replay([
      captured("t1", "book flights", lamport: 1),
      completed("t1", lamport: 2),
      projectCreated("p1", "Holiday", lamport: 3),
      moved("t1", to: "p1", lamport: 4),
    ])

    #expect(state.projects == [project("p1", "Holiday")])
    #expect(state.openTasks == [])
  }
}

@Suite("When a project is completed")
struct ProjectCompletionReplayTests {
  static let log = [
    captured("t1", "book flights", lamport: 1),
    captured("t2", "buy milk", lamport: 2),
    projectCreated("p1", "Holiday", lamport: 3),
    moved("t1", to: "p1", lamport: 4),
    projectCompleted("p1", lamport: 5),
  ]

  @Test("it leaves the projects list")
  func completedProjectIsNotListed() {
    #expect(LibraryState.replay(Self.log).projects == [])
  }

  @Test("its open tasks are no longer open")
  func completedProjectClosesItsTasks() {
    #expect(LibraryState.replay(Self.log).openTasks == [item("t2", "buy milk")])
  }

  @Test("a task filed into it afterwards stays where it was")
  func filingIntoACompletedProjectIsIgnored() {
    let state = LibraryState.replay(Self.log + [moved("t2", to: "p1", lamport: 6)])

    #expect(state.inbox == [item("t2", "buy milk")])
  }
}

@Suite("When project events arrive in any order")
struct ProjectReplayOrderTests {
  static let log = [
    captured("t1", "book flights", device: "mac", lamport: 1),
    captured("t2", "pack", device: "air", lamport: 1),
    projectCreated("p1", "Holiday", kind: .sequential, device: "mac", lamport: 2),
    moved("t2", to: "p1", device: "air", lamport: 3),
    moved("t1", to: "p1", device: "mac", lamport: 3),
  ]

  @Test("replay gives the same state", arguments: [[0, 1, 2, 3, 4], [4, 3, 2, 1, 0], [2, 4, 0, 3, 1]])
  func anyArrivalOrderReplaysToTheSameState(order: [Int]) {
    let state = LibraryState.replay(order.map { Self.log[$0] })

    // Same lamport: device ID breaks the tie, "air" before "mac".
    #expect(state.projects.first?.tasks.map(\.title) == ["pack", "book flights"])
  }
}

@Suite("Next actions of a project")
struct NextActionTests {
  static let tasks = [item("t1", "find a flat", in: "p1"), item("t2", "sign the lease", in: "p1")]

  @Test("in a parallel project, every open task is one")
  func parallelProjectOffersEveryTask() {
    #expect(project("p1", "Move house", kind: .parallel, tasks: Self.tasks).nextActions == Self.tasks)
  }

  @Test("in a sequential project, only the first open task is one")
  func sequentialProjectOffersTheFirstTask() {
    #expect(project("p1", "Move house", kind: .sequential, tasks: Self.tasks).nextActions == [Self.tasks[0]])
  }

  @Test("an empty project has none", arguments: [ProjectKind.parallel, .sequential])
  func emptyProjectOffersNothing(kind: ProjectKind) {
    #expect(project("p1", "Move house", kind: kind).nextActions == [])
  }
}
