import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When a project is created under another")
struct SubprojectCreationReplayTests {
  @Test("it is nested in it, after the children added before it")
  func createdSubprojectJoinsTheEndOfTheParent() {
    let state = LibraryState.replay([
      projectCreated("p1", "Home", lamport: 1),
      captured("t1", "clear the attic", lamport: 2),
      moved("t1", to: "p1", lamport: 3),
      projectCreated("p2", "Kitchen", under: "p1", lamport: 4),
    ])

    #expect(
      state.view(.default).projects == [
        project("p1", "Home", children: [.task(item("t1", "clear the attic", in: "p1")), sub("p2")]),
        project("p2", "Kitchen", under: "p1"),
      ])
  }

  @Test("under a project that is not active, it is top-level")
  func createdUnderAnUnknownProjectIsTopLevel() {
    let state = LibraryState.replay([projectCreated("p2", "Kitchen", under: "p9", lamport: 1)])

    #expect(state.view(.default).projects == [project("p2", "Kitchen")])
  }

  @Test("under a project of another view, it is top-level")
  func createdUnderAProjectOfAnotherViewIsTopLevel() {
    let state = LibraryState.replay([
      viewCreated("v1", "Work", lamport: 1),
      projectCreated("p1", "Home", lamport: 2),
      projectCreated("p2", "Q4 plan", under: "p1", view: "v1", lamport: 3),
    ])

    #expect(state.view(.default).projects == [project("p1", "Home")])
    #expect(state.view(ViewID("v1")).projects == [project("p2", "Q4 plan", view: "v1")])
  }
}

@Suite("When a project is moved into another")
struct NestingReplayTests {
  static let log = [
    projectCreated("p1", "Home", lamport: 1),
    projectCreated("p2", "Kitchen", lamport: 2),
    projectCreated("p3", "Tap", lamport: 3),
    nested("p2", under: "p1", lamport: 4),
  ]

  @Test("it is nested in it and no longer top-level")
  func nestedProjectIsAChildOfItsParent() {
    let view = LibraryState.replay(Self.log).view(.default)

    #expect(view.topLevelProjects.map(\.id) == [ProjectID("p1"), ProjectID("p3")])
    #expect(view.subprojects(of: ProjectID("p1")).map(\.id) == [ProjectID("p2")])
    #expect(view.projects.first { $0.id == ProjectID("p2") }?.parentID == ProjectID("p1"))
  }

  @Test("it can be nested to any depth")
  func projectsNestToAnyDepth() {
    let view = LibraryState.replay(Self.log + [nested("p3", under: "p2", lamport: 5)]).view(.default)

    #expect(view.topLevelProjects.map(\.id) == [ProjectID("p1")])
    #expect(view.subprojects(of: ProjectID("p2")).map(\.id) == [ProjectID("p3")])
  }

  @Test("moving it under another parent takes it out of the first")
  func renestingMovesTheProject() {
    let view = LibraryState.replay(Self.log + [nested("p2", under: "p3", lamport: 5)]).view(.default)

    #expect(view.subprojects(of: ProjectID("p1")) == [])
    #expect(view.subprojects(of: ProjectID("p3")).map(\.id) == [ProjectID("p2")])
  }

  @Test("moving it to the top makes it top-level again")
  func unnestingMakesItTopLevel() {
    let view = LibraryState.replay(Self.log + [nested("p2", under: nil, lamport: 5)]).view(.default)

    #expect(view.topLevelProjects.map(\.id) == [ProjectID("p1"), ProjectID("p2"), ProjectID("p3")])
    #expect(view.projects.first { $0.id == ProjectID("p1") }?.children == [])
  }

  @Test("nesting it again under the same parent keeps its place")
  func renestingUnderTheSameParentChangesNothing() {
    let log = Self.log + [
      nested("p3", under: "p1", lamport: 5),
      nested("p2", under: "p1", id: "again", lamport: 6),
    ]

    let view = LibraryState.replay(log).view(.default)

    #expect(view.subprojects(of: ProjectID("p1")).map(\.id) == [ProjectID("p2"), ProjectID("p3")])
  }
}

@Suite("When a nesting cannot apply")
struct IgnoredNestingReplayTests {
  static let log = [
    projectCreated("p1", "Home", lamport: 1),
    projectCreated("p2", "Kitchen", under: "p1", lamport: 2),
  ]

  @Test(
    "the tree stays as it was",
    arguments: [
      nested("p1", under: "p1", lamport: 3),
      nested("p1", under: "p2", lamport: 3),
      nested("p1", under: "p9", lamport: 3),
      nested("p9", under: "p1", lamport: 3),
    ])
  func impossibleNestingIsIgnored(event: EventEnvelope) {
    #expect(LibraryState.replay(Self.log + [event]) == LibraryState.replay(Self.log))
  }

  @Test("a parent in another view is ignored")
  func nestingAcrossViewsIsIgnored() {
    let log = Self.log + [
      viewCreated("v1", "Work", lamport: 3),
      projectCreated("p3", "Q4 plan", view: "v1", lamport: 4),
    ]

    #expect(LibraryState.replay(log + [nested("p3", under: "p1", lamport: 5)]) == LibraryState.replay(log))
  }

  @Test("a completed parent is ignored")
  func nestingUnderACompletedProjectIsIgnored() {
    let log = Self.log + [projectCreated("p3", "Garden", lamport: 3), projectCompleted("p1", lamport: 4)]

    #expect(LibraryState.replay(log + [nested("p3", under: "p1", lamport: 5)]) == LibraryState.replay(log))
  }
}

@Suite("When two devices nest two projects under each other")
struct ConcurrentNestingReplayTests {
  static let log = [
    projectCreated("p1", "Home", lamport: 1),
    projectCreated("p2", "Kitchen", lamport: 2),
    nested("p2", under: "p1", device: "air", lamport: 3),
    nested("p1", under: "p2", device: "mac", lamport: 3),
  ]

  @Test(
    "the first in replay order wins, whatever the arrival order",
    arguments: [[0, 1, 2, 3], [3, 2, 1, 0], [1, 3, 0, 2]])
  func cycleIsBrokenDeterministically(order: [Int]) {
    let view = LibraryState.replay(order.map { Self.log[$0] }).view(.default)

    // Same lamport: device ID breaks the tie, "air" before "mac".
    #expect(view.topLevelProjects.map(\.id) == [ProjectID("p1")])
    #expect(view.subprojects(of: ProjectID("p1")).map(\.id) == [ProjectID("p2")])
  }
}

@Suite("When a task is filed into a sub-project")
struct SubprojectFilingReplayTests {
  @Test("it is a child of the sub-project, not of its parent")
  func filedTaskBelongsToTheSubproject() {
    let state = LibraryState.replay([
      projectCreated("p1", "Home", lamport: 1),
      projectCreated("p2", "Kitchen", under: "p1", lamport: 2),
      captured("t1", "replace the tap", lamport: 3),
      moved("t1", to: "p2", lamport: 4),
    ])

    #expect(
      state.view(.default).projects == [
        project("p1", "Home", children: [sub("p2")]),
        project("p2", "Kitchen", under: "p1", tasks: [item("t1", "replace the tap", in: "p2")]),
      ])
  }
}

@Suite("When a project with sub-projects is completed")
struct NestedCompletionReplayTests {
  static let log = [
    projectCreated("p1", "Home", lamport: 1),
    projectCreated("p2", "Kitchen", under: "p1", lamport: 2),
    projectCreated("p3", "Tap", under: "p2", lamport: 3),
    captured("t1", "clear the attic", lamport: 4),
    captured("t2", "buy a washer", lamport: 5),
    captured("t3", "buy milk", lamport: 6),
    moved("t1", to: "p1", lamport: 7),
    moved("t2", to: "p3", lamport: 8),
  ]

  @Test("its sub-projects and their open tasks are gone, all the way down")
  func completingAProjectCompletesItsSubtree() {
    let view = LibraryState.replay(Self.log + [projectCompleted("p1", lamport: 9)]).view(.default)

    #expect(view.projects == [])
    #expect(view.openTasks == [item("t3", "buy milk")])
  }

  @Test("completing a sub-project leaves its parent, without it")
  func completingASubprojectLeavesTheParent() {
    let view = LibraryState.replay(Self.log + [projectCompleted("p2", lamport: 9)]).view(.default)

    #expect(view.projects == [project("p1", "Home", tasks: [item("t1", "clear the attic", in: "p1")])])
    #expect(view.openTasks == [item("t1", "clear the attic", in: "p1"), item("t3", "buy milk")])
  }
}

@Suite("When a project with sub-projects is moved to another view")
struct NestedViewMoveReplayTests {
  static let log = [
    viewCreated("v1", "Work", lamport: 1),
    projectCreated("p1", "Home", lamport: 2),
    projectCreated("p2", "Kitchen", under: "p1", lamport: 3),
    projectCreated("p3", "Tap", under: "p2", lamport: 4),
    captured("t1", "buy a washer", lamport: 5),
    moved("t1", to: "p3", lamport: 6),
  ]

  @Test("the whole subtree goes with it")
  func movingAProjectMovesItsSubtree() {
    let state = LibraryState.replay(Self.log + [projectMovedToView("p1", toView: "v1", lamport: 7)])

    #expect(state.view(.default).projects == [])
    #expect(state.view(.default).openTasks == [])
    #expect(
      state.view(ViewID("v1")).projects == [
        project("p1", "Home", view: "v1", children: [sub("p2")]),
        project("p2", "Kitchen", view: "v1", under: "p1", children: [sub("p3")]),
        project("p3", "Tap", view: "v1", under: "p2", tasks: [item("t1", "buy a washer", in: "p3", view: "v1")]),
      ])
  }

  @Test("a sub-project moved alone is top-level there, and its parent stays without it")
  func movingASubprojectUnnestsIt() {
    let state = LibraryState.replay(Self.log + [projectMovedToView("p2", toView: "v1", lamport: 7)])

    #expect(state.view(.default).projects == [project("p1", "Home")])
    #expect(state.view(ViewID("v1")).topLevelProjects.map(\.id) == [ProjectID("p2")])
    #expect(state.view(ViewID("v1")).subprojects(of: ProjectID("p2")).map(\.id) == [ProjectID("p3")])
  }
}

@Suite("Next actions of nested projects")
struct NestedNextActionTests {
  /// Home holds, in this order: the sub-project Kitchen (tasks "replace the tap", "paint the wall"), then
  /// the task "clear the attic".
  static func home(_ home: ProjectKind, kitchen: ProjectKind) -> ViewState {
    LibraryState.replay([
      projectCreated("p1", "Home", kind: home, lamport: 1),
      projectCreated("p2", "Kitchen", kind: kitchen, under: "p1", lamport: 2),
      captured("t1", "replace the tap", lamport: 3),
      captured("t2", "paint the wall", lamport: 4),
      captured("t3", "clear the attic", lamport: 5),
      moved("t1", to: "p2", lamport: 6),
      moved("t2", to: "p2", lamport: 7),
      moved("t3", to: "p1", lamport: 8),
    ]).view(.default)
  }

  struct Case: Sendable {
    let home: ProjectKind
    let kitchen: ProjectKind
    let expected: [String]
  }

  @Test(
    "the project hands out its sub-project's next actions as its own child's",
    arguments: [
      Case(home: .parallel, kitchen: .parallel, expected: ["t1", "t2", "t3"]),
      Case(home: .parallel, kitchen: .sequential, expected: ["t1", "t3"]),
      Case(home: .sequential, kitchen: .parallel, expected: ["t1", "t2"]),
      Case(home: .sequential, kitchen: .sequential, expected: ["t1"]),
    ])
  func nextActionsAreRecursive(case kinds: Case) {
    let view = Self.home(kinds.home, kitchen: kinds.kitchen)

    #expect(view.nextActions(of: ProjectID("p1")).map(\.id.rawValue) == kinds.expected)
    #expect(view.nextActions.map(\.id.rawValue) == kinds.expected)
  }

  @Test("a sub-project's task is a next action only if every ancestor lets it be")
  func ancestorsGateTheirSubprojects() {
    let view = LibraryState.replay([
      projectCreated("p1", "Home", kind: .sequential, lamport: 1),
      captured("t1", "clear the attic", lamport: 2),
      moved("t1", to: "p1", lamport: 3),
      projectCreated("p2", "Kitchen", under: "p1", lamport: 4),
      captured("t2", "replace the tap", lamport: 5),
      moved("t2", to: "p2", lamport: 6),
    ]).view(.default)

    #expect(view.nextActions(of: ProjectID("p2")).map(\.id.rawValue) == ["t2"])
    #expect(view.nextActions.map(\.id.rawValue) == ["t1"])
  }

  @Test("an empty sub-project first in a sequential project holds back the rest")
  func emptySubprojectBlocksASequentialParent() {
    let view = LibraryState.replay([
      projectCreated("p1", "Home", kind: .sequential, lamport: 1),
      projectCreated("p2", "Kitchen", under: "p1", lamport: 2),
      captured("t1", "clear the attic", lamport: 3),
      moved("t1", to: "p1", lamport: 4),
    ]).view(.default)

    #expect(view.nextActions(of: ProjectID("p1")) == [])
  }

  @Test("a project of another view has none here")
  func projectOfAnotherViewHasNoNextActions() {
    let view = LibraryState.replay([
      viewCreated("v1", "Work", lamport: 1),
      projectCreated("p1", "Q4 plan", view: "v1", lamport: 2),
      captured("t1", "write the report", view: "v1", lamport: 3),
      moved("t1", to: "p1", lamport: 4),
    ]).view(.default)

    #expect(view.nextActions(of: ProjectID("p1")) == [])
    #expect(view.nextActions == [])
  }
}
