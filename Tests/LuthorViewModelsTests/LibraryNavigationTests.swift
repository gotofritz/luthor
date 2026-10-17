import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("When the window opens")
struct NavigationStartTests {
  @Test("the inbox section is shown")
  func windowOpensOnTheInbox() {
    let (library, _) = makeInbox()

    #expect(library.section == .inbox)
  }

  @Test("the sections are the inbox, the projects and the priorities")
  func sectionsAreInboxProjectsPriorities() {
    #expect(NavigationSection.allCases == [.inbox, .projects, .priorities])
  }
}

@MainActor
@Suite("When another section is picked")
struct NavigationSectionTests {
  static let log = [
    captured("t1", "buy milk", lamport: 1),
    captured("t2", "find a flat", lamport: 2),
    projectCreated("p1", "Move house", lamport: 3),
    moved("t2", to: "p1", lamport: 4),
    prioritized("t1", as: .critical, lamport: 5),
  ]

  @Test("picking the projects shows no project yet")
  func projectsStartWithNoProjectOpen() {
    let (library, _) = makeInbox(Self.log)

    library.show(.projects)

    #expect(library.section == .projects)
    #expect(library.path == [])
    #expect(library.columns.first?.entries.map(\.id) == ["project-p1"])
  }

  @Test("opening a project shows the projects section")
  func openingAProjectShowsProjects() {
    let (library, _) = makeInbox(Self.log)

    library.open(.project(ProjectID("p1")))

    #expect(library.section == .projects)
  }

  @Test("opening the inbox shows the inbox section")
  func openingTheInboxShowsTheInbox() {
    let (library, _) = makeInbox(Self.log)
    library.open(.project(ProjectID("p1")))

    library.open(.inbox)

    #expect(library.section == .inbox)
  }

  @Test("leaving the projects closes the open project")
  func leavingProjectsClosesTheProject() {
    let (library, _) = makeInbox(Self.log)
    library.open(.project(ProjectID("p1")))

    library.show(.inbox)

    #expect(library.sidebarSelection == .inbox)
    #expect(library.tasks == [item("t1", "buy milk", priority: .critical)])
  }

  @Test("the selection is cleared")
  func pickingASectionClearsTheSelection() {
    let (library, _) = makeInbox(Self.log)
    library.selection = TaskID("t1")

    library.show(.priorities)

    #expect(library.selection == nil)
  }

  @Test("switching view shows the inbox section")
  func switchingViewShowsTheInbox() {
    let (library, _) = makeInbox(Self.log + [viewCreated("v1", "Work", lamport: 6)])
    library.show(.priorities)

    library.showView(ViewID("v1"))

    #expect(library.section == .inbox)
  }
}

@MainActor
@Suite("When priorities are picked")
struct PriorityPickTests {
  static let log = [
    captured("t1", "low", lamport: 1),
    captured("t2", "urgent", lamport: 2),
    captured("t3", "later", lamport: 3),
    captured("t4", "unranked", lamport: 4),
    prioritized("t1", as: .optional, lamport: 5),
    prioritized("t2", as: .critical, lamport: 6),
    prioritized("t3", as: .someday, lamport: 7),
  ]

  @Test("none picked lists nothing")
  func noPriorityPickedListsNothing() {
    let (library, _) = makeInbox(Self.log)

    library.show(.priorities)

    #expect(library.selectedPriorities == [])
    #expect(library.tasks == [])
  }

  @Test("picking one lists its tasks")
  func pickingOneListsItsTasks() {
    let (library, _) = makeInbox(Self.log)
    library.show(.priorities)

    library.togglePriority(.critical)

    #expect(library.selectedPriorities == [.critical])
    #expect(library.tasks == [item("t2", "urgent", priority: .critical)])
  }

  @Test("picking a second keeps the first, and the most urgent are listed first")
  func pickingASecondAddsToTheFirst() {
    let (library, _) = makeInbox(Self.log)
    library.show(.priorities)
    library.togglePriority(.optional)

    library.togglePriority(.critical)

    #expect(library.selectedPriorities == [.optional, .critical])
    #expect(library.tasks.map(\.id.rawValue) == ["t2", "t1"])
  }

  @Test("picking a picked one drops it")
  func pickingAgainDropsIt() {
    let (library, _) = makeInbox(Self.log)
    library.show(.priorities)
    library.togglePriority(.optional)
    library.togglePriority(.critical)

    library.togglePriority(.optional)

    #expect(library.selectedPriorities == [.critical])
    #expect(library.tasks.map(\.id.rawValue) == ["t2"])
  }

  @Test("the tasks are next actions unless a project holds them back")
  func priorityTasksKnowTheirNextActions() {
    let (library, _) = makeInbox(
      Self.log + [
        captured("t5", "first step", lamport: 8),
        captured("t6", "second step", lamport: 9),
        projectCreated("p1", "Move house", kind: .sequential, lamport: 10),
        moved("t5", to: "p1", lamport: 11),
        moved("t6", to: "p1", lamport: 12),
        prioritized("t5", as: .critical, lamport: 13),
        prioritized("t6", as: .critical, lamport: 14),
      ])
    library.show(.priorities)

    library.togglePriority(.critical)

    #expect(library.nextActions == [TaskID("t2"), TaskID("t5")])
  }

  @Test("a task completed from the list leaves it")
  func completingAPriorityTaskRemovesIt() {
    let (library, _) = makeInbox(Self.log)
    library.show(.priorities)
    library.togglePriority(.critical)
    library.moveSelection(by: 1)

    library.completeSelected()

    #expect(library.tasks == [])
  }
}

@MainActor
@Suite("When a task is given a priority")
struct PrioritizeViewModelTests {
  @Test("it carries the priority, and the event is written")
  func prioritizeWritesTheEvent() {
    let (library, log) = makeInbox([captured("t1", "buy milk", lamport: 1)])

    library.prioritize(TaskID("t1"), as: .important)

    #expect(log.events.last == prioritized("t1", as: .important, id: "id-1", lamport: 2))
    #expect(library.tasks == [item("t1", "buy milk", priority: .important)])
  }

  @Test("the selected task takes it")
  func prioritizeSelectedUsesTheSelection() {
    let (library, _) = makeInbox([captured("t1", "buy milk", lamport: 1)])
    library.selection = TaskID("t1")

    library.prioritizeSelected(as: .critical)

    #expect(library.tasks.first?.priority == .critical)
  }

  @Test("with nothing selected nothing is written")
  func prioritizeSelectedWithoutSelectionWritesNothing() {
    let (library, log) = makeInbox([captured("t1", "buy milk", lamport: 1)])

    library.prioritizeSelected(as: .critical)

    #expect(log.events == [captured("t1", "buy milk", lamport: 1)])
  }

  @Test("clearing it removes the priority")
  func clearingRemovesThePriority() {
    let (library, _) = makeInbox([captured("t1", "buy milk", lamport: 1), prioritized("t1", as: .critical)])

    library.prioritize(TaskID("t1"), as: nil)

    #expect(library.tasks.first?.priority == nil)
  }

  @Test("a task prioritised in the list drops out of a list that no longer matches")
  func reprioritisingLeavesTheShownPriority() {
    let (library, _) = makeInbox([captured("t1", "buy milk", lamport: 1), prioritized("t1", as: .critical)])
    library.show(.priorities)
    library.togglePriority(.critical)

    library.prioritize(TaskID("t1"), as: .optional)

    #expect(library.tasks == [])
  }
}
