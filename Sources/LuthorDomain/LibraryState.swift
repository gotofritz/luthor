/// A view as the view switcher lists it.
public struct ViewItem: Equatable, Sendable {
  public let id: ViewID
  public let name: String

  public init(id: ViewID, name: String) {
    self.id = id
    self.name = name
  }
}

public struct TaskItem: Equatable, Sendable {
  public let id: TaskID
  public let title: String
  public let viewID: ViewID
  /// The project the task is filed in; `nil` while it is in the inbox.
  public let projectID: ProjectID?

  public init(id: TaskID, title: String, viewID: ViewID, projectID: ProjectID? = nil) {
    self.id = id
    self.title = title
    self.viewID = viewID
    self.projectID = projectID
  }
}

/// What a project holds: an open task, or an active sub-project.
public enum ProjectChild: Equatable, Sendable {
  case task(TaskItem)
  case project(ProjectID)
}

public struct Project: Equatable, Sendable {
  public let id: ProjectID
  public let title: String
  public let kind: ProjectKind
  public fileprivate(set) var viewID: ViewID
  /// The project it is nested in; `nil` for a top-level project.
  public fileprivate(set) var parentID: ProjectID?
  /// Open tasks and active sub-projects, in the order they were added to the project.
  public fileprivate(set) var children: [ProjectChild]

  public init(
    id: ProjectID,
    title: String,
    kind: ProjectKind,
    viewID: ViewID,
    parentID: ProjectID? = nil,
    children: [ProjectChild] = []
  ) {
    self.id = id
    self.title = title
    self.kind = kind
    self.viewID = viewID
    self.parentID = parentID
    self.children = children
  }

  /// Open tasks filed straight into the project, in the order they were filed.
  public var tasks: [TaskItem] {
    children.compactMap { child in
      guard case .task(let task) = child else { return nil }
      return task
    }
  }
}

/// What one view holds. Everything a list shows comes from here, so nothing of another view can reach it.
public struct ViewState: Equatable, Sendable {
  public let id: ViewID
  /// Every open task of the view, in the inbox or in a project, in capture order.
  public let openTasks: [TaskItem]
  /// Active projects of the view in creation order.
  public let projects: [Project]

  /// Open tasks of the view not yet filed into a project, in capture order.
  public var inbox: [TaskItem] {
    openTasks.filter { $0.projectID == nil }
  }

  /// Projects of the view that are nested in none, in creation order.
  public var topLevelProjects: [Project] {
    projects
  }

  /// The active sub-projects of a project, in the order they were added to it.
  public func subprojects(of projectID: ProjectID) -> [Project] {
    []
  }

  /// The tasks of a project's subtree that the project hands out, as if it had no parent.
  public func nextActions(of projectID: ProjectID) -> [TaskItem] {
    []
  }

  /// The tasks of the view's projects that can be worked on now: every ancestor lets them be.
  public var nextActions: [TaskItem] {
    []
  }
}

/// The state of every view. Tasks and projects are reachable only through `view(_:)`, which names the
/// view: isolation between views is a rule of the domain, not a filter in the UI.
public struct LibraryState: Equatable, Sendable {
  /// The default view, then the others in creation order.
  public private(set) var views = [ViewItem(id: .default, name: "Default")]
  /// Every open task of every view, in capture order.
  private(set) var openTasks: [TaskItem] = []
  /// Every active project of every view, in creation order.
  private(set) var projects: [Project] = []

  /// The open tasks and active projects of one view; empty for a view that does not exist.
  public func view(_ viewID: ViewID) -> ViewState {
    ViewState(
      id: viewID,
      openTasks: openTasks.filter { $0.viewID == viewID },
      projects: projects.filter { $0.viewID == viewID }
    )
  }

  /// The view with this name, ignoring case.
  public func view(named name: String) -> ViewItem? {
    views.first { $0.name.lowercased() == name.lowercased() }
  }

  /// Builds state from events in any arrival order. Duplicates (same event ID) apply once.
  public static func replay(_ events: [EventEnvelope]) -> LibraryState {
    var state = LibraryState()
    var seen = Set<EventID>()
    for event in events.sorted(by: EventEnvelope.replayOrder) where seen.insert(event.id).inserted {
      state.apply(event.payload)
    }
    return state
  }

  mutating func apply(_ payload: EventPayload) {
    switch payload {
    case .taskCaptured(let captured):
      openTasks.append(TaskItem(id: captured.taskID, title: captured.title, viewID: captured.viewID))
    case .taskCompleted(let completed):
      openTasks.removeAll { $0.id == completed.taskID }
      removeFromProjects(completed.taskID)
    case .projectCreated(let created):
      guard !projects.contains(where: { $0.id == created.projectID }) else { return }
      projects.append(Project(id: created.projectID, title: created.title, kind: created.kind, viewID: created.viewID))
    case .taskMovedToProject(let moved):
      move(moved.taskID, to: moved.projectID)
    case .projectCompleted(let completed):
      openTasks.removeAll { $0.projectID == completed.projectID }
      projects.removeAll { $0.id == completed.projectID }
    case .viewCreated(let created):
      create(created)
    case .viewRenamed(let renamed):
      rename(renamed)
    case .taskMovedToView(let moved):
      move(moved.taskID, toView: moved.viewID)
    case .projectMovedToView(let moved):
      move(moved.projectID, toView: moved.viewID)
    case .projectMovedToProject:
      break
    }
  }

  func hasView(_ viewID: ViewID) -> Bool {
    views.contains { $0.id == viewID }
  }

  /// Ignores a view that already exists.
  private mutating func create(_ created: ViewCreated) {
    guard !hasView(created.viewID) else { return }
    views.append(ViewItem(id: created.viewID, name: created.name))
  }

  /// Ignores a view that does not exist.
  private mutating func rename(_ renamed: ViewRenamed) {
    guard let index = views.firstIndex(where: { $0.id == renamed.viewID }) else { return }
    views[index] = ViewItem(id: renamed.viewID, name: renamed.name)
  }

  /// Ignores a task that is not open, a project that is not active or in another view, and a task
  /// already in the project.
  private mutating func move(_ taskID: TaskID, to projectID: ProjectID) {
    guard let index = openTasks.firstIndex(where: { $0.id == taskID }),
      let target = projects.firstIndex(where: { $0.id == projectID }),
      openTasks[index].projectID != projectID,
      openTasks[index].viewID == projects[target].viewID
    else { return }
    let task = openTasks[index]
    let filed = TaskItem(id: taskID, title: task.title, viewID: task.viewID, projectID: projectID)
    openTasks[index] = filed
    removeFromProjects(taskID)
    projects[target].children.append(.task(filed))
  }

  /// Ignores a task that is not open and a view that does not exist.
  private mutating func move(_ taskID: TaskID, toView viewID: ViewID) {
    guard let index = openTasks.firstIndex(where: { $0.id == taskID }), hasView(viewID) else { return }
    openTasks[index] = TaskItem(id: taskID, title: openTasks[index].title, viewID: viewID)
    removeFromProjects(taskID)
  }

  /// Ignores a project that is not active and a view that does not exist.
  private mutating func move(_ projectID: ProjectID, toView viewID: ViewID) {
    guard let target = projects.firstIndex(where: { $0.id == projectID }), hasView(viewID) else { return }
    let reassign = { (task: TaskItem) in
      TaskItem(id: task.id, title: task.title, viewID: viewID, projectID: task.projectID)
    }
    openTasks = openTasks.map { $0.projectID == projectID ? reassign($0) : $0 }
    projects[target].viewID = viewID
    projects[target].children = projects[target].children.map { child in
      guard case .task(let task) = child else { return child }
      return .task(reassign(task))
    }
  }

  private mutating func removeFromProjects(_ taskID: TaskID) {
    for index in projects.indices {
      projects[index].children.removeAll { child in
        guard case .task(let task) = child else { return false }
        return task.id == taskID
      }
    }
  }
}
