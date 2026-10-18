import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// Holiday holds the empty project Pack and the project Spain, which holds a task; Taxes is empty and apart.
private let holidayLog = [
  projectCreated("p1", "Holiday", lamport: 1),
  projectCreated("p2", "Pack", under: "p1", lamport: 2),
  projectCreated("p3", "Spain", under: "p1", lamport: 3),
  captured("t1", "book flights", under: "p3", lamport: 4),
  projectCreated("p4", "Taxes", lamport: 5),
]

@MainActor
@Suite("When a project is turned into a task in the window")
struct DemoteViewModelTests {
  @Test("an empty project is written as a task and listed in its parent")
  func anEmptyProjectBecomesATask() {
    let (library, log) = makeInbox(holidayLog)
    library.open(.project(TaskID("p1")))

    library.turnIntoTask(TaskID("p2"))

    #expect(log.events.last == demoted("p2", id: "id-1", lamport: 6))
    #expect(library.tasks.map(\.id) == [TaskID("p2")])
    #expect(library.projects.map(\.id) == [TaskID("p1"), TaskID("p3"), TaskID("p4")])
  }

  @Test("if the columns showed it, its parent is shown with the new task selected")
  func theParentIsShownWithTheTaskSelected() {
    let (library, _) = makeInbox(holidayLog)
    library.open(.project(TaskID("p2")))

    library.turnIntoTask(TaskID("p2"))

    #expect(library.shownProject?.id == TaskID("p1"))
    #expect(library.selection == TaskID("p2"))
    #expect(library.cardTarget == .task(TaskID("p2")))
  }

  @Test("a top-level one that was shown leaves no project shown")
  func aTopLevelOneLeavesNoProjectShown() {
    let (library, _) = makeInbox(holidayLog)
    library.open(.project(TaskID("p4")))

    library.turnIntoTask(TaskID("p4"))

    #expect(library.shownProject == nil)
    #expect(library.projects.map(\.id) == [TaskID("p1"), TaskID("p2"), TaskID("p3")])
  }

  @Test("a project with something in it writes nothing")
  func aProjectWithChildrenWritesNothing() {
    let (library, log) = makeInbox(holidayLog)

    library.turnIntoTask(TaskID("p3"))

    #expect(log.events == holidayLog)
    #expect(library.errorMessage == nil)
  }

  @Test("a project that is not on the path leaves what is shown as it is")
  func aProjectOffThePathChangesNothing() {
    let (library, _) = makeInbox(holidayLog)
    library.open(.project(TaskID("p3")))

    library.turnIntoTask(TaskID("p4"))

    #expect(library.path == [TaskID("p1"), TaskID("p3")])
  }
}
