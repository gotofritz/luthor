import LuthorDomain
import LuthorStore
import Observation

/// The main window: one view at a time, with the sidebar of its inbox and projects, the open tasks of
/// the one shown, the capture fields and the keyboard selection. Everything listed comes from the
/// current view's state, so nothing of another view is ever shown.
///
/// Every action re-reads the log first, so events another process appended (the CLI) are never missed
/// and new events follow the highest Lamport counter on disk.
@MainActor
@Observable
public final class LibraryViewModel {
  /// Every view, the default one first.
  public internal(set) var views: [ViewItem] = []
  /// The one view the window shows; nothing from another view is ever listed.
  public internal(set) var currentView: ViewID
  /// The place the navigation rail has picked.
  public internal(set) var section = NavigationSection.inbox
  public internal(set) var sidebarSelection: SidebarItem = .inbox
  /// The priorities picked in the priorities section; they add up, so the list shows all of them.
  public internal(set) var selectedPriorities: Set<Priority> = []
  /// Every active project of the view, nested or not, in creation order.
  public internal(set) var projects: [Project] = []
  /// The project browser: the top-level projects, then one column for each project on the path.
  public internal(set) var columns: [ProjectColumn] = []
  /// The shown project and its ancestors, top-level first; empty while the inbox is shown.
  public internal(set) var path: [ProjectID] = []
  /// Open tasks of the inbox, of the project shown, or with a priority picked.
  public internal(set) var tasks: [TaskItem] = []
  /// The shown tasks that can be worked on now. Every inbox task is one.
  public internal(set) var nextActions: Set<TaskID> = []
  /// The settings with no per-view override applied.
  public internal(set) var globalSettings = LibraryState.replay([]).globalSettings
  /// The settings `currentView` plans with: its own overrides, then the global values.
  public internal(set) var viewSettings = LibraryState.replay([]).settings(for: .default)
  /// The view `luthor add` and imports use when none is named.
  public internal(set) var defaultViewID = ViewID.default
  /// The day it is by the clock as of the last refresh, the day whose plan Today shows, that plan (planned
  /// tasks, candidates, capacity) for the current view, and the view's delegated tasks, longest wait first.
  public internal(set) var today: CalendarDate
  public internal(set) var planDate: CalendarDate
  public internal(set) var plan: DayPlan
  public internal(set) var waiting: [WaitingItem] = []
  /// Whether completed tasks and projects are listed too, dimmed, after the open ones.
  public var showCompleted = false {
    didSet { present() }
  }
  /// Of the completed items listed, those that can be reopened and those that came with their project.
  public internal(set) var completedTaskIDs: Set<TaskID> = []
  public internal(set) var completedProjectIDs: Set<ProjectID> = []
  public internal(set) var reopenableTaskIDs: Set<TaskID> = []
  public internal(set) var reopenableProjectIDs: Set<ProjectID> = []
  public var draft = ""
  /// Title of the next project to create.
  public var projectDraft = ""
  public var selection: TaskID?
  /// The task the Delegate dialog is asking about; the menus set it, the window shows the dialog.
  public var delegatingTaskID: TaskID?
  public internal(set) var errorMessage: String?

  let log: any EventLog
  let clock: () -> CalendarDate
  let commands: Commands
  @ObservationIgnored var state = LibraryState.replay([])

  /// `today` tells the day it is; the default is the system clock.
  public init(
    log: any EventLog,
    commands: Commands,
    view: ViewID = .default,
    today: @escaping () -> CalendarDate = { CalendarDate.systemToday() }
  ) {
    self.log = log
    self.commands = commands
    clock = today
    currentView = view
    let day = today()
    self.today = day
    planDate = day
    plan = LibraryState.replay([]).plan(for: view, on: day, today: day)
  }

  /// Shows another view, at its inbox, with no task selected.
  public func showView(_ viewID: ViewID) {
    currentView = viewID
    section = .inbox
    sidebarSelection = .inbox
    selection = nil
    present()
  }

  /// Creates a view and shows it. A blank name, or one another view has, creates nothing.
  public func createView(named name: String) {
    let created = perform { (log) throws(CommandError) in try commands.createView(name: name, log: log) }
    for case .viewCreated(let view) in created.map(\.payload) {
      showView(view.viewID)
    }
  }

  /// Renames a view. A blank name, or one another view has, changes nothing.
  public func renameView(_ viewID: ViewID, to name: String) {
    perform { (log) throws(CommandError) in try commands.renameView(viewID, to: name, log: log) }
  }

  /// Takes a task across to another view, into its inbox.
  public func move(_ taskID: TaskID, toView viewID: ViewID) {
    perform { (log) throws(CommandError) in try commands.move(taskID: taskID, toView: viewID, log: log) }
  }

  /// Takes the selected task across to another view and selects the one that takes its place.
  public func moveSelected(toView viewID: ViewID) {
    replaceSelected { move($0, toView: viewID) }
  }

  /// Takes a project and its open tasks across to another view. If the sidebar showed it, it shows the
  /// inbox again.
  public func moveProject(_ projectID: ProjectID, toView viewID: ViewID) {
    perform { (log) throws(CommandError) in try commands.move(projectID: projectID, toView: viewID, log: log) }
  }

  /// What a project carries when dragged, so a drop can tell it from a task.
  public static func dragPayload(for projectID: ProjectID) -> String {
    projectPayloadPrefix + projectID.rawValue
  }

  private static let projectPayloadPrefix = "project:"

  /// Handles payloads dropped on a project, or on the first column (`nil`): a project is nested there or
  /// made top-level, a task is filed into the project. Returns whether anything was dropped.
  @discardableResult
  public func drop(_ payloads: [String], on target: ProjectID?) -> Bool {
    for payload in payloads {
      if payload.hasPrefix(Self.projectPayloadPrefix) {
        nest(ProjectID(String(payload.dropFirst(Self.projectPayloadPrefix.count))), under: target)
      } else if let target {
        file(TaskID(payload), into: target)
      }
    }
    return !payloads.isEmpty
  }

  /// Nests a project in another, or with no parent makes it top-level. Nesting it under itself or one of
  /// its own sub-projects changes nothing.
  public func nest(_ projectID: ProjectID, under parentID: ProjectID?) {
    perform { (log) throws(CommandError) in try commands.move(projectID: projectID, under: parentID, log: log) }
  }

  public func reload() {
    do {
      show(try log.readAll())
    } catch {
      errorMessage = Self.describe(error)
    }
  }

  /// Captures the draft as a new task. A blank draft captures nothing; a failed write keeps the draft.
  public func submit() {
    let title = draft
    let projectID = shownProjectID
    let viewID = currentView
    perform { (log) throws(CommandError) in
      if let projectID {
        try commands.capture(title: title, into: projectID, log: log)
      } else {
        try commands.capture(title: title, in: viewID, log: log)
      }
    }
    if errorMessage == nil { draft = "" }
  }

  /// Shows the inbox or a project, with no task selected.
  public func open(_ item: SidebarItem) {
    switch item {
    case .inbox: section = .inbox
    case .project: section = .projects
    }
    sidebarSelection = item
    selection = nil
    present()
  }

  /// Shows a section of the navigation rail, with no task selected. Leaving the projects closes the
  /// project shown.
  public func show(_ section: NavigationSection) {
    self.section = section
    if section != .projects { sidebarSelection = .inbox }
    selection = nil
    present()
  }

  /// Picks a priority or, if it is picked, drops it. The others stay as they are.
  public func togglePriority(_ priority: Priority) {
    if !selectedPriorities.insert(priority).inserted { selectedPriorities.remove(priority) }
    present()
  }

  /// Gives a task a priority, or with `nil` clears it.
  public func prioritize(_ taskID: TaskID, as priority: Priority?) {
    perform { (log) throws(CommandError) in try commands.prioritize(taskID: taskID, as: priority, log: log) }
  }

  /// Gives the selected task a priority, or with `nil` clears it.
  public func prioritizeSelected(as priority: Priority?) {
    guard let selected = selection else { return }
    prioritize(selected, as: priority)
  }

  /// Gives a task an estimate in minutes, or with `nil` clears it.
  public func estimate(_ taskID: TaskID, as minutes: Int?) {
    perform { (log) throws(CommandError) in try commands.estimate(taskID: taskID, as: minutes, log: log) }
  }

  /// Gives the selected task an estimate in minutes, or with `nil` clears it.
  public func estimateSelected(as minutes: Int?) {
    guard let selected = selection else { return }
    estimate(selected, as: minutes)
  }

  /// Creates a project titled by the project draft, inside the project shown, or top-level while the
  /// inbox is shown. A blank draft creates nothing; a failed write keeps the draft.
  public func createProject(kind: ProjectKind) {
    let title = projectDraft
    let viewID = currentView
    let parentID = shownProjectID
    perform { (log) throws(CommandError) in
      if let parentID {
        try commands.createProject(title: title, kind: kind, under: parentID, log: log)
      } else {
        try commands.createProject(title: title, kind: kind, in: viewID, log: log)
      }
    }
    if errorMessage == nil { projectDraft = "" }
  }

  /// Files a task into a project.
  public func file(_ taskID: TaskID, into projectID: ProjectID) {
    perform { (log) throws(CommandError) in try commands.move(taskID: taskID, to: projectID, log: log) }
  }

  /// Files the selected task and selects the one that takes its place in the list.
  public func fileSelected(into projectID: ProjectID) {
    replaceSelected { file($0, into: projectID) }
  }

  /// Completes a project and its open tasks. If the sidebar showed it, it shows the inbox again.
  public func completeProject(_ projectID: ProjectID) {
    perform { (log) throws(CommandError) in try commands.completeProject(projectID, log: log) }
  }

  /// Opens a completed task again; a task that its project's completion took along stays completed.
  public func reopen(_ taskID: TaskID) {
    perform { (log) throws(CommandError) in try commands.reopen(taskID: taskID, log: log) }
  }

  /// Opens a completed project again, with what its completion took along.
  public func reopenProject(_ projectID: ProjectID) {
    perform { (log) throws(CommandError) in try commands.reopenProject(projectID, log: log) }
  }

  public func complete(_ taskID: TaskID) {
    perform { (log) throws(CommandError) in try commands.complete(taskID: taskID, log: log) }
  }

  /// Moves the selection up (negative) or down (positive), stopping at the ends. With nothing selected,
  /// down selects the first task and up the last.
  public func moveSelection(by offset: Int) {
    guard let current = selection.flatMap(index(of:)) else {
      selection = (offset < 0 ? tasks.last : tasks.first)?.id
      return
    }
    selection = tasks[min(max(current + offset, 0), tasks.count - 1)].id
  }

  /// Completes the selected task and selects the one that takes its place in the list.
  public func completeSelected() {
    replaceSelected(complete)
  }
}
