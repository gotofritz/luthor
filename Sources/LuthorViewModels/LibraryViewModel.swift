import LuthorDomain
import LuthorStore
import Observation

/// What the sidebar can show: the inbox or one active project.
public enum SidebarItem: Hashable, Sendable {
  case inbox
  case project(ProjectID)
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
  public private(set) var sidebarSelection: SidebarItem = .inbox
  /// Active projects in creation order.
  public private(set) var projects: [Project] = []
  /// Open tasks of the inbox, or of the project the sidebar shows.
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
    sidebarSelection = item
    selection = nil
    present()
  }

  /// Creates a project titled by the project draft. A blank draft creates nothing; a failed write keeps
  /// the draft.
  public func createProject(kind: ProjectKind) {
    let title = projectDraft
    let viewID = currentView
    perform { (log) throws(CommandError) in
      try commands.createProject(title: title, kind: kind, in: viewID, log: log)
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
    if let projectID = shownProjectID, let project = projects.first(where: { $0.id == projectID }) {
      tasks = project.tasks
      nextActions = Set(project.nextActions.map(\.id))
    } else {
      tasks = view.inbox
      nextActions = Set(tasks.map(\.id))
    }
    if let selected = selection, index(of: selected) == nil { selection = nil }
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
