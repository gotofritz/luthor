import LuthorDomain
import LuthorStore
import Observation

/// What the sidebar can show: the inbox or one active project.
public enum SidebarItem: Hashable, Sendable {
  case inbox
  case project(ProjectID)
}

/// The places the navigation rail leads to, in the order it lists them.
public enum NavigationSection: Hashable, Sendable, CaseIterable {
  case inbox
  case projects
  case priorities
}

/// One entry of a column: a sub-project to open, or a task.
public enum ColumnEntry: Equatable, Sendable, Identifiable {
  case project(Project)
  case task(TaskItem)

  public var id: String {
    switch self {
    case .project(let project): "project-\(project.id.rawValue)"
    case .task(let task): "task-\(task.id.rawValue)"
    }
  }
}

/// One column of the project browser: the top-level projects, or the children of one project.
public struct ProjectColumn: Equatable, Sendable, Identifiable {
  /// The project whose children the column lists; `nil` for the first column, of top-level projects.
  public let parentID: ProjectID?
  public let entries: [ColumnEntry]

  public init(parentID: ProjectID?, entries: [ColumnEntry]) {
    self.parentID = parentID
    self.entries = entries
  }

  public var id: String {
    parentID.map { "project-\($0.rawValue)" } ?? "top"
  }
}

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
  public private(set) var views: [ViewItem] = []
  /// The one view the window shows; nothing from another view is ever listed.
  public private(set) var currentView: ViewID
  /// The place the navigation rail has picked.
  public private(set) var section = NavigationSection.inbox
  public private(set) var sidebarSelection: SidebarItem = .inbox
  /// The priorities picked in the priorities section; they add up, so the list shows all of them.
  public private(set) var selectedPriorities: Set<Priority> = []
  /// Every active project of the view, nested or not, in creation order.
  public private(set) var projects: [Project] = []
  /// The project browser: the top-level projects, then one column for each project on the path.
  public private(set) var columns: [ProjectColumn] = []
  /// The shown project and its ancestors, top-level first; empty while the inbox is shown.
  public private(set) var path: [ProjectID] = []
  /// Open tasks of the inbox, of the project shown, or with a priority picked.
  public private(set) var tasks: [TaskItem] = []
  /// The shown tasks that can be worked on now. Every inbox task is one.
  public private(set) var nextActions: Set<TaskID> = []
  public var draft = ""
  /// Title of the next project to create.
  public var projectDraft = ""
  public var selection: TaskID?
  public private(set) var errorMessage: String?

  private let log: any EventLog
  private let commands: Commands
  @ObservationIgnored private var state = LibraryState.replay([])

  public init(log: any EventLog, commands: Commands, view: ViewID = .default) {
    self.log = log
    self.commands = commands
    currentView = view
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

// Internals: reading and writing the log, and filling the published state from it. Split from the
// class body above (SwiftLint type_body_length) rather than suppressed.
extension LibraryViewModel {
  /// Applies `action` to the selected task; if that takes it off the list, selects the task that takes
  /// its place.
  private func replaceSelected(_ action: (TaskID) -> Void) {
    guard let selected = selection, let position = index(of: selected) else { return }
    action(selected)
    guard !tasks.contains(where: { $0.id == selected }) else { return }
    selection = tasks.isEmpty ? nil : tasks[min(position, tasks.count - 1)].id
  }

  /// Runs a command on the log as it is now and appends what it returns; returns the events written.
  @discardableResult
  private func perform(_ command: ([EventEnvelope]) throws(CommandError) -> [EventEnvelope]) -> [EventEnvelope] {
    let current: [EventEnvelope]
    do {
      current = try log.readAll()
    } catch {
      errorMessage = Self.describe(error)
      return []
    }
    let events: [EventEnvelope]
    do {
      events = try command(current)
    } catch {
      // A blank title, a view name already taken, or a task completed elsewhere since the last reload:
      // nothing to write, and nothing the user needs to fix.
      show(current)
      return []
    }
    do {
      try log.append(events)
    } catch {
      errorMessage = Self.describe(error)
      return []
    }
    show(current + events)
    return events
  }

  private func show(_ events: [EventEnvelope]) {
    state = LibraryState.replay(events)
    errorMessage = nil
    present()
  }

  /// Fills the view switcher, the sidebar and the list from the current view of the last replayed state.
  private func present() {
    views = state.views
    if !views.contains(where: { $0.id == currentView }) {
      // A remembered view this log does not have.
      currentView = .default
    }
    let view = state.view(currentView)
    projects = view.projects
    if let projectID = shownProjectID, !projects.contains(where: { $0.id == projectID }) {
      // Completed here or elsewhere: there is nothing left to show.
      sidebarSelection = .inbox
    }
    path = shownProjectID.map { ancestry(of: $0) } ?? []
    var columns = [ProjectColumn(parentID: nil, entries: view.topLevelProjects.map { .project($0) })]
    for projectID in path {
      guard let project = projects.first(where: { $0.id == projectID }) else { continue }
      columns.append(ProjectColumn(parentID: projectID, entries: project.children.compactMap { entry($0) }))
    }
    self.columns = columns
    if section == .priorities {
      tasks = view.tasks(prioritised: selectedPriorities)
      let actionable = Set(view.nextActions.map(\.id))
      nextActions = Set(tasks.filter { $0.projectID == nil || actionable.contains($0.id) }.map(\.id))
    } else if let projectID = shownProjectID, let project = projects.first(where: { $0.id == projectID }) {
      tasks = project.tasks
      let shown = columns.flatMap(\.entries).compactMap { entry -> TaskID? in
        guard case .task(let task) = entry else { return nil }
        return task.id
      }
      nextActions = Set(view.nextActions.map(\.id)).intersection(shown)
    } else {
      tasks = view.inbox
      nextActions = Set(tasks.map(\.id))
    }
    if let selected = selection, index(of: selected) == nil { selection = nil }
  }

  /// The project and its ancestors, top-level first.
  private func ancestry(of projectID: ProjectID) -> [ProjectID] {
    var path: [ProjectID] = []
    var current: ProjectID? = projectID
    while let id = current, !path.contains(id), let project = projects.first(where: { $0.id == id }) {
      path.insert(id, at: 0)
      current = project.parentID
    }
    return path
  }

  /// A child as a column shows it; `nil` for a sub-project that is not in the view.
  private func entry(_ child: ProjectChild) -> ColumnEntry? {
    switch child {
    case .task(let task):
      return .task(task)
    case .project(let projectID):
      guard let project = projects.first(where: { $0.id == projectID }) else { return nil }
      return .project(project)
    }
  }

  private var shownProjectID: ProjectID? {
    guard case .project(let projectID) = sidebarSelection else { return nil }
    return projectID
  }

  private func index(of taskID: TaskID) -> Int? {
    tasks.firstIndex { $0.id == taskID }
  }

  private static func describe(_ error: EventLogError) -> String {
    switch error {
    case .unreadableLine(let number): "Line \(number) of the event log is not a readable event."
    case .ioFailure(let message): message
    }
  }
}
