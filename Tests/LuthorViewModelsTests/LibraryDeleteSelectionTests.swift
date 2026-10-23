import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// Holiday holds Spain, which holds Beaches and the tasks "book flights" and "pack"; Taxes is apart.
private let holidayLog = [
  projectCreated("p1", "Holiday", lamport: 1),
  projectCreated("p2", "Spain", under: "p1", lamport: 2),
  projectCreated("p3", "Beaches", under: "p2", lamport: 3),
  captured("t1", "book flights", under: "p2", lamport: 4),
  captured("t2", "pack", under: "p2", lamport: 5),
  projectCreated("p4", "Taxes", lamport: 6),
]

@MainActor
@Suite("When a project is deleted for good while the columns show it")
struct DeleteShownProjectViewModelTests {
  @Test("its parent is shown")
  func theParentIsShown() {
    let (library, _) = makeInbox(holidayLog)
    library.open(.project(TaskID("p2")))

    library.deleteProject(TaskID("p2"))

    #expect(library.shownProject?.id == TaskID("p1"))
    #expect(library.path == [TaskID("p1")])
    #expect(library.cardTarget == nil)
  }

  @Test("so is the parent when a project further down the path was the one shown")
  func theParentIsShownWhenALaterColumnWas() {
    let (library, _) = makeInbox(holidayLog)
    library.open(.project(TaskID("p3")))

    library.deleteProject(TaskID("p2"))

    #expect(library.shownProject?.id == TaskID("p1"))
    #expect(library.path == [TaskID("p1")])
  }

  @Test("a top-level project that was shown leaves the first column with nothing shown")
  func aTopLevelProjectLeavesNothingShown() {
    let (library, _) = makeInbox(holidayLog)
    library.open(.project(TaskID("p4")))

    library.deleteProject(TaskID("p4"))

    #expect(library.shownProject == nil)
    #expect(library.path.isEmpty)
  }

  @Test("a project that is not on the path leaves what is shown as it is")
  func aProjectOffThePathChangesNothing() {
    let (library, _) = makeInbox(holidayLog)
    library.open(.project(TaskID("p2")))
    library.selection = TaskID("t1")

    library.deleteProject(TaskID("p4"))

    #expect(library.path == [TaskID("p1"), TaskID("p2")])
    #expect(library.selection == TaskID("t1"))
  }
}

@MainActor
@Suite("When a task is deleted for good")
struct DeleteSelectedTaskViewModelTests {
  @Test("its project stays shown")
  func theProjectStaysShown() {
    let (library, _) = makeInbox(holidayLog)
    library.open(.project(TaskID("p2")))
    library.selection = TaskID("t1")

    library.deleteTask(TaskID("t1"))

    #expect(library.path == [TaskID("p1"), TaskID("p2")])
    #expect(library.selection == nil)
    #expect(library.cardTarget == nil)
  }

  @Test("somewhere other than the columns, the place shown stays")
  func otherPlacesStay() {
    let (library, _) = makeInbox(holidayLog)
    library.show(.today)

    library.deleteTask(TaskID("t1"))

    #expect(library.section == .today)
  }
}
