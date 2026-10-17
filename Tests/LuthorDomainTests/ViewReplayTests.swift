import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When the log is empty")
struct EmptyLogViewTests {
  @Test("replay creates the default view")
  func replayCreatesTheDefaultView() {
    #expect(LibraryState.replay([]).views == [ViewItem(id: .default, name: "Default")])
  }
}

@Suite("When views are created and renamed")
struct ViewLifecycleReplayTests {
  @Test("they are listed after the default view, in creation order")
  func createdViewsFollowTheDefaultView() {
    let state = LibraryState.replay([viewCreated("v2", "Private", lamport: 2), viewCreated("v1", "Work", lamport: 1)])

    #expect(state.views.map(\.name) == ["Default", "Work", "Private"])
  }

  @Test("creating one again under the same ID changes nothing")
  func recreatingAViewIsIgnored() {
    let state = LibraryState.replay([
      viewCreated("v1", "Work", id: "e1", lamport: 1),
      viewCreated("v1", "Other", id: "e2", lamport: 2),
    ])

    #expect(state.views.map(\.name) == ["Default", "Work"])
  }

  @Test("renaming one keeps its place")
  func renamingKeepsThePlace() {
    let state = LibraryState.replay([
      viewCreated("v1", "Work", lamport: 1),
      viewRenamed("default", to: "Private", lamport: 2),
    ])

    #expect(state.views == [ViewItem(id: .default, name: "Private"), ViewItem(id: ViewID("v1"), name: "Work")])
  }

  @Test("renaming an unknown view changes nothing")
  func renamingAnUnknownViewIsIgnored() {
    #expect(LibraryState.replay([viewRenamed("v9", to: "Work", lamport: 1)]).views.map(\.name) == ["Default"])
  }

  @Test("a view is found by its name, ignoring case")
  func viewsAreFoundByName() {
    let state = LibraryState.replay([viewCreated("v1", "Work", lamport: 1)])

    #expect(state.view(named: "work") == ViewItem(id: ViewID("v1"), name: "Work"))
    #expect(state.view(named: "Home") == nil)
  }
}

@Suite("When events carry no view")
struct DefaultViewReplayTests {
  @Test("their tasks and projects belong to the default view")
  func eventsWithoutAViewBelongToTheDefaultView() {
    let state = LibraryState.replay([
      captured("t1", "buy milk", lamport: 1), projectCreated("p1", "Holiday", lamport: 2),
    ])

    #expect(state.view(.default).inbox == [item("t1", "buy milk")])
    #expect(state.view(.default).projects == [project("p1", "Holiday")])
  }
}

/// A Work view next to the default view, each with an inbox task and a project holding a task.
private let twoViews = [
  viewCreated("work", "Work", lamport: 1),
  captured("w1", "write the report", view: "work", lamport: 2),
  captured("w2", "plan the offsite", view: "work", lamport: 3),
  projectCreated("wp", "Q4 plan", kind: .sequential, view: "work", lamport: 4),
  moved("w2", to: "wp", lamport: 5),
  captured("h1", "buy milk", lamport: 6),
  captured("h2", "book flights", lamport: 7),
  projectCreated("hp", "Holiday", lamport: 8),
  moved("h2", to: "hp", lamport: 9),
]

/// Every list a view exposes, as task or project IDs, so each can be checked for leaks.
enum ViewList: String, CaseIterable, Sendable {
  case inbox, openTasks, projects, projectTasks, nextActions, projectNextActions

  func ids(in view: ViewState) -> Set<String> {
    switch self {
    case .inbox: Set(view.inbox.map(\.id.rawValue))
    case .openTasks: Set(view.openTasks.map(\.id.rawValue))
    case .projects: Set(view.projects.map(\.id.rawValue))
    case .projectTasks: Set(view.projects.flatMap(\.tasks).map(\.id.rawValue))
    case .nextActions: Set(view.nextActions.map(\.id.rawValue))
    case .projectNextActions: Set(view.projects.flatMap { view.nextActions(of: $0.id) }.map(\.id.rawValue))
    }
  }
}

@Suite("Given a Work view and the default view")
struct ViewIsolationReplayTests {
  static let work = Set(["w1", "w2", "wp"])
  static let home = Set(["h1", "h2", "hp"])

  @Test("nothing from Work appears in the default view", arguments: ViewList.allCases)
  func workNeverLeaksIntoTheDefaultView(list: ViewList) {
    let ids = list.ids(in: LibraryState.replay(twoViews).view(.default))

    #expect(!ids.isEmpty)
    #expect(ids.isDisjoint(with: Self.work))
  }

  @Test("nothing from the default view appears in Work", arguments: ViewList.allCases)
  func theDefaultViewNeverLeaksIntoWork(list: ViewList) {
    let ids = list.ids(in: LibraryState.replay(twoViews).view(ViewID("work")))

    #expect(!ids.isEmpty)
    #expect(ids.isDisjoint(with: Self.home))
  }

  @Test("an unknown view is empty")
  func anUnknownViewIsEmpty() {
    let view = LibraryState.replay(twoViews).view(ViewID("v9"))

    #expect(view.openTasks.isEmpty && view.projects.isEmpty)
  }

  @Test("a task filed into a project of the other view stays where it is")
  func filingAcrossViewsIsIgnored() {
    let state = LibraryState.replay(twoViews + [moved("h1", to: "wp", lamport: 10)])

    #expect(state.view(.default).inbox == [item("h1", "buy milk")])
    #expect(state.view(ViewID("work")).projects.first?.tasks.map(\.title) == ["plan the offsite"])
  }
}

@Suite("When a task is moved to another view")
struct TaskMovedToViewReplayTests {
  @Test("it leaves its project and lands in the other view's inbox")
  func movedTaskLandsInTheOtherInbox() {
    let state = LibraryState.replay(twoViews + [movedToView("h2", toView: "work", lamport: 10)])

    #expect(state.view(.default).projects == [project("hp", "Holiday")])
    #expect(
      state.view(ViewID("work")).inbox == [
        item("w1", "write the report", view: "work"), item("h2", "book flights", view: "work"),
      ])
  }

  @Test("a move to an unknown view changes nothing")
  func movingToAnUnknownViewIsIgnored() {
    let state = LibraryState.replay(twoViews + [movedToView("h1", toView: "v9", lamport: 10)])

    #expect(state == LibraryState.replay(twoViews))
  }
}

@Suite("When a project is moved to another view")
struct ProjectMovedToViewReplayTests {
  @Test("it takes its open tasks with it")
  func movedProjectTakesItsTasks() {
    let state = LibraryState.replay(twoViews + [projectMovedToView("hp", toView: "work", lamport: 10)])

    #expect(state.view(.default).projects.isEmpty)
    #expect(state.view(.default).openTasks.map(\.title) == ["buy milk"])
    #expect(
      state.view(ViewID("work")).projects.last
        == project("hp", "Holiday", view: "work", tasks: [item("h2", "book flights", in: "hp", view: "work")]))
  }

  @Test("a move to an unknown view changes nothing")
  func movingToAnUnknownViewIsIgnored() {
    let state = LibraryState.replay(twoViews + [projectMovedToView("hp", toView: "v9", lamport: 10)])

    #expect(state == LibraryState.replay(twoViews))
  }
}
