import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// A Work view next to the default view, each with an inbox task and a project holding a task.
private let twoViews = [
  viewCreated("work", "Work", lamport: 1),
  captured("w1", "write the report", view: "work", lamport: 2),
  captured("w2", "plan the offsite", view: "work", lamport: 3),
  projectCreated("wp", "Q4 plan", view: "work", lamport: 4),
  moved("w2", to: "wp", lamport: 5),
  captured("h1", "buy milk", lamport: 6),
  captured("h2", "book flights", lamport: 7),
  projectCreated("hp", "Holiday", kind: .sequential, lamport: 8),
  moved("h2", to: "hp", lamport: 9),
]

@MainActor
private func makeLibrary(_ events: [EventEnvelope] = twoViews, view: ViewID = .default) -> (
  LibraryViewModel, InMemoryEventLog
) {
  let log = InMemoryEventLog(events)
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()), view: view,
    today: { date("2026-10-19") })
  library.reload()
  return (library, log)
}

@MainActor
@Suite("When the window opens on a view")
struct ViewLaunchViewModelTests {
  @Test("the view switcher lists every view, the default one first")
  func viewsAreListed() {
    let (library, _) = makeLibrary()

    #expect(library.views == [ViewItem(id: .default, name: "Default"), ViewItem(id: ViewID("work"), name: "Work")])
  }

  @Test("the lists show only that view")
  func listsShowOnlyThatView() {
    let (library, _) = makeLibrary(view: ViewID("work"))

    #expect(library.currentView == ViewID("work"))
    #expect(library.tasks.map(\.title) == ["write the report"])
    #expect(library.projects.map(\.title) == ["Q4 plan"])
  }

  @Test("a remembered view that no longer exists falls back to the default view")
  func unknownViewFallsBackToTheDefault() {
    let (library, _) = makeLibrary(view: ViewID("gone"))

    #expect(library.currentView == .default)
    #expect(library.tasks.map(\.title) == ["buy milk"])
  }
}

/// Every list the window shows, as task or project IDs, so each can be checked for leaks.
enum WindowList: String, CaseIterable, Sendable {
  case inbox, today, projects, projectTasks, nextActions

  @MainActor
  func ids(in library: LibraryViewModel) -> Set<String> {
    switch self {
    case .inbox:
      library.open(.inbox)
      return Set(library.tasks.map(\.id.rawValue))
    case .today:
      library.show(.today)
      return Set(library.tasks.map(\.id.rawValue))
    case .projects:
      return Set(library.projects.map(\.id.rawValue))
    case .projectTasks, .nextActions:
      var ids = Set<String>()
      for project in library.projects {
        library.open(.project(project.id))
        ids.formUnion(self == .projectTasks ? library.tasks.map(\.id.rawValue) : library.nextActions.map(\.rawValue))
      }
      return ids
    }
  }
}

@MainActor
@Suite("Given a Work view and the default view in the window")
struct ViewIsolationViewModelTests {
  @Test("nothing from Work is listed in the default view", arguments: WindowList.allCases)
  func workNeverLeaksIntoTheDefaultView(list: WindowList) {
    let (library, _) = makeLibrary(view: ViewID("work"))
    library.showView(.default)

    let ids = list.ids(in: library)

    #expect(!ids.isEmpty)
    #expect(ids.isDisjoint(with: ["w1", "w2", "wp"]))
  }

  @Test("nothing from the default view is listed in Work", arguments: WindowList.allCases)
  func theDefaultViewNeverLeaksIntoWork(list: WindowList) {
    let (library, _) = makeLibrary()
    library.showView(ViewID("work"))

    let ids = list.ids(in: library)

    #expect(!ids.isEmpty)
    #expect(ids.isDisjoint(with: ["h1", "h2", "hp"]))
  }
}

@MainActor
@Suite("When the window switches view")
struct ViewSwitchingViewModelTests {
  @Test("it shows that view's inbox, with nothing selected")
  func switchingShowsTheInboxOfTheView() {
    let (library, _) = makeLibrary()
    library.open(.project(ProjectID("hp")))
    library.selection = TaskID("h2")

    library.showView(ViewID("work"))

    #expect(library.currentView == ViewID("work"))
    #expect(library.sidebarSelection == .inbox)
    #expect(library.selection == nil)
    #expect(library.tasks.map(\.title) == ["write the report"])
  }

  @Test("tasks and projects created there belong to it")
  func capturesGoIntoTheCurrentView() {
    let (library, log) = makeLibrary()
    library.showView(ViewID("work"))
    library.draft = "book a room"
    library.submit()
    library.projectDraft = "Offsite"
    library.createProject(kind: .parallel)

    #expect(
      log.events.suffix(2) == [
        captured("id-2", "book a room", id: "id-1", view: "work", on: "2026-10-19", lamport: 10),
        projectCreated("id-4", "Offsite", id: "id-3", view: "work", on: "2026-10-19", lamport: 11),
      ])
  }
}

@MainActor
@Suite("When a view is created or renamed from the view switcher")
struct ViewManagementViewModelTests {
  @Test("a new view is listed and shown")
  func createdViewIsShown() {
    let (library, log) = makeLibrary([])

    library.createView(named: "Work")

    #expect(log.events == [viewCreated("id-2", "Work", id: "id-1", lamport: 1)])
    #expect(library.views.map(\.name) == ["Default", "Work"])
    #expect(library.currentView == ViewID("id-2"))
  }

  @Test("a blank or taken name creates nothing", arguments: ["  ", "work"])
  func invalidNameCreatesNothing(name: String) {
    let (library, log) = makeLibrary()

    library.createView(named: name)

    #expect(log.events == twoViews)
    #expect(library.currentView == .default)
  }

  @Test("renaming a view lists it under the new name")
  func renamedViewIsListed() {
    let (library, _) = makeLibrary()

    library.renameView(.default, to: "Private")

    #expect(library.views.map(\.name) == ["Private", "Work"])
  }
}

@MainActor
@Suite("When a task or project is moved to another view")
struct ViewMoveViewModelTests {
  @Test("the task leaves the list and shows in the other view's inbox")
  func movedTaskLeavesTheList() {
    let (library, _) = makeLibrary()

    library.move(TaskID("h1"), toView: ViewID("work"))

    #expect(library.tasks.isEmpty)
    library.showView(ViewID("work"))
    #expect(library.tasks.map(\.title) == ["write the report", "buy milk"])
  }

  @Test("moving the selected task selects the one that takes its place")
  func moveSelectedSelectsTheNextTask() {
    let (library, _) = makeLibrary(twoViews + [captured("h3", "call mum", lamport: 10)])
    library.selection = TaskID("h1")

    library.moveSelected(toView: ViewID("work"))

    #expect(library.selection == TaskID("h3"))
  }

  @Test("a project moved away leaves the sidebar, and if shown, the inbox is shown")
  func movedProjectLeavesTheSidebar() {
    let (library, _) = makeLibrary()
    library.open(.project(ProjectID("hp")))

    library.moveProject(ProjectID("hp"), toView: ViewID("work"))

    #expect(library.projects.isEmpty)
    #expect(library.sidebarSelection == .inbox)
    library.showView(ViewID("work"))
    #expect(library.projects.map(\.title) == ["Q4 plan", "Holiday"])
  }
}
