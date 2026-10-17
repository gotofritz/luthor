import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When a task is renamed")
struct TaskRenameReplayTests {
  @Test("the open task has the new title")
  func renamedTaskHasTheNewTitle() {
    let log = [captured("t1", "buy mlik", lamport: 1), renamed("t1", to: "buy milk", lamport: 2)]

    #expect(LibraryState.replay(log).view(.default).openTasks == [item("t1", "buy milk")])
  }

  @Test("so does the copy in its project")
  func renamedTaskIsRenamedInItsProject() {
    let log = [
      projectCreated("p1", "Holiday", lamport: 1), captured("t1", "book flights", lamport: 2),
      moved("t1", to: "p1", lamport: 3), renamed("t1", to: "book trains", lamport: 4),
    ]

    #expect(
      LibraryState.replay(log).view(.default).projects == [
        project("p1", "Holiday", tasks: [item("t1", "book trains", in: "p1")])
      ])
  }

  @Test("a completed task keeps its title")
  func completedTaskIsNotRenamed() {
    let log = [captured("t1", "buy milk", lamport: 1), completed("t1", lamport: 2), renamed("t1", to: "x", lamport: 3)]

    #expect(LibraryState.replay(log).view(.default).completedTasks.map(\.item.title) == ["buy milk"])
  }
}

@Suite("When a task is given notes")
struct TaskNotesReplayTests {
  @Test("the task carries them")
  func notedTaskCarriesTheNotes() {
    let log = [captured("t1", "buy milk", lamport: 1), noted("t1", "oat, not soy", lamport: 2)]

    #expect(LibraryState.replay(log).view(.default).openTasks == [item("t1", "buy milk", notes: "oat, not soy")])
  }

  @Test("clearing them leaves none")
  func clearedNotesAreGone() {
    let log = [captured("t1", "buy milk", lamport: 1), noted("t1", "oat", lamport: 2), noted("t1", nil, lamport: 3)]

    #expect(LibraryState.replay(log).view(.default).openTasks == [item("t1", "buy milk")])
  }

  @Test("they follow the task into a project, a completion and a reopening")
  func notesSurviveMovesAndCompletion() {
    let log = [
      captured("t1", "buy milk", lamport: 1), noted("t1", "oat", lamport: 2), projectCreated("p1", "Shop", lamport: 3),
      moved("t1", to: "p1", lamport: 4), prioritized("t1", as: .critical, lamport: 5), completed("t1", lamport: 6),
    ]
    let completedView = LibraryState.replay(log).view(.default)
    let reopenedView = LibraryState.replay(log + [reopened("t1", lamport: 7)]).view(.default)

    #expect(completedView.completedTasks.map(\.item.notes) == ["oat"])
    #expect(reopenedView.openTasks.map(\.notes) == ["oat"])
  }

  @Test("the task keeps them when it is filed, prioritized or sent to another view")
  func notesSurviveEdits() {
    let log = [
      viewCreated("v2", "Work", lamport: 1), captured("t1", "report", lamport: 2), noted("t1", "q3", lamport: 3),
      estimated("t1", as: 30, lamport: 4), movedToView("t1", toView: "v2", lamport: 5),
    ]

    #expect(
      LibraryState.replay(log).view(ViewID("v2")).openTasks
        == [item("t1", "report", view: "v2", estimate: 30, notes: "q3")])
  }

  @Test("notes on a task that is not open are ignored")
  func notesOnACompletedTaskAreIgnored() {
    let log = [captured("t1", "buy milk", lamport: 1), completed("t1", lamport: 2), noted("t1", "late", lamport: 3)]

    #expect(LibraryState.replay(log).view(.default).completedTasks.map(\.item.notes) == [nil])
  }
}

@Suite("When a project is edited")
struct ProjectCardReplayTests {
  static let log = [
    projectCreated("p1", "Holiday", kind: .parallel, lamport: 1), captured("t1", "book flights", lamport: 2),
    captured("t2", "pack", lamport: 3), moved("t1", to: "p1", lamport: 4), moved("t2", to: "p1", lamport: 5),
  ]

  @Test("renaming it gives it the new title and keeps its tasks")
  func renamedProjectKeepsItsTasks() {
    let state = LibraryState.replay(Self.log + [projectRenamed("p1", to: "Summer", lamport: 6)])

    #expect(
      state.view(.default).projects == [
        project(
          "p1", "Summer", tasks: [item("t1", "book flights", in: "p1"), item("t2", "pack", in: "p1")])
      ])
  }

  @Test("it can be made sequential, which holds back all but its first task")
  func sequentialProjectHoldsBackLaterTasks() {
    let view = LibraryState.replay(Self.log + [kindChanged("p1", to: .sequential, lamport: 6)]).view(.default)

    #expect(view.projects.first?.kind == .sequential)
    #expect(view.nextActions.map(\.title) == ["book flights"])
  }

  @Test("and back to parallel")
  func backToParallel() {
    let log = Self.log + [kindChanged("p1", to: .sequential, lamport: 6), kindChanged("p1", to: .parallel, lamport: 7)]
    let view = LibraryState.replay(log).view(.default)

    #expect(view.nextActions.map(\.title) == ["book flights", "pack"])
  }

  @Test("notes are set and cleared")
  func projectNotes() {
    let withNotes = LibraryState.replay(Self.log + [projectNoted("p1", "https://example.com", lamport: 6)])
    let cleared = LibraryState.replay(
      Self.log + [projectNoted("p1", "x", lamport: 6), projectNoted("p1", nil, lamport: 7)])

    #expect(withNotes.view(.default).projects.first?.notes == "https://example.com")
    #expect(cleared.view(.default).projects.first?.notes == nil)
  }

  @Test("a completed project is not edited")
  func completedProjectIsNotEdited() {
    let log =
      Self.log + [
        projectCompleted("p1", lamport: 6), projectRenamed("p1", to: "x", lamport: 7),
        kindChanged("p1", to: .sequential, lamport: 8), projectNoted("p1", "late", lamport: 9),
      ]
    let completedProject = LibraryState.replay(log).view(.default).completedProjects.first?.item

    #expect(completedProject?.title == "Holiday")
    #expect(completedProject?.kind == .parallel)
    #expect(completedProject?.notes == nil)
  }

  @Test("the edits keep a project's place among its parent's children")
  func editsKeepTheTree() {
    let log = [
      projectCreated("p1", "Home", lamport: 1), projectCreated("p2", "Kitchen", under: "p1", lamport: 2),
      projectRenamed("p2", to: "Cooking", lamport: 3), kindChanged("p2", to: .sequential, lamport: 4),
    ]

    #expect(
      LibraryState.replay(log).view(.default).projects == [
        project("p1", "Home", children: [sub("p2")]),
        project("p2", "Cooking", kind: .sequential, under: "p1"),
      ])
  }
}
