import LuthorDomain
import LuthorStore
import Observation

/// What the sidebar can show: the inbox or one active project.
public enum SidebarItem: Hashable, Sendable {
  case inbox
  case project(ProjectID)
}

/// The main window: the sidebar of inbox and projects, the open tasks of the one shown, the capture
/// fields and the keyboard selection.
///
/// Every action re-reads the log first, so events another process appended (the CLI) are never missed
/// and new events follow the highest Lamport counter on disk.
@MainActor
@Observable
public final class LibraryViewModel {
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

  public init(log: any EventLog, commands: Commands) {
    self.log = log
    self.commands = commands
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
    perform { (log) throws(CommandError) in try commands.capture(title: title, into: projectID, log: log) }
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
    perform { (log) throws(CommandError) in try commands.createProject(title: title, kind: kind, log: log) }
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

  private func perform(_ command: ([EventEnvelope]) throws(CommandError) -> [EventEnvelope]) {
    let current: [EventEnvelope]
    do {
      current = try log.readAll()
    } catch {
      errorMessage = Self.describe(error)
      return
    }
    let events: [EventEnvelope]
    do {
      events = try command(current)
    } catch {
      // A blank title, or a task completed elsewhere since the last reload: nothing to write, and
      // nothing the user needs to fix.
      show(current)
      return
    }
    do {
      try log.append(events)
    } catch {
      errorMessage = Self.describe(error)
      return
    }
    show(current + events)
  }

  private func show(_ events: [EventEnvelope]) {
    state = LibraryState.replay(events)
    errorMessage = nil
    present()
  }

  /// Fills the sidebar and the list from the last replayed state.
  private func present() {
    projects = state.projects
    if let projectID = shownProjectID, !projects.contains(where: { $0.id == projectID }) {
      // Completed here or elsewhere: there is nothing left to show.
      sidebarSelection = .inbox
    }
    if let projectID = shownProjectID, let project = projects.first(where: { $0.id == projectID }) {
      tasks = project.tasks
      nextActions = Set(project.nextActions.map(\.id))
    } else {
      tasks = state.inbox
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
