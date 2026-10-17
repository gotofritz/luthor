/// What one view holds. Everything a list shows comes from here, so nothing of another view can reach it.
public struct ViewState: Equatable, Sendable {
  public let id: ViewID
  /// Every open task of the view, in the inbox or in a project, in capture order.
  public let openTasks: [TaskItem]
  /// Active projects of the view in creation order.
  public let projects: [Project]
  /// Completed tasks of the view, in the order they were completed.
  public let completedTasks: [Completed<TaskItem>]
  /// Completed projects of the view, in the order they were completed.
  public let completedProjects: [Completed<Project>]

  init(
    id: ViewID,
    openTasks: [TaskItem],
    projects: [Project],
    completedTasks: [Completed<TaskItem>] = [],
    completedProjects: [Completed<Project>] = []
  ) {
    self.id = id
    self.openTasks = openTasks
    self.projects = projects
    self.completedTasks = completedTasks
    self.completedProjects = completedProjects
  }

  /// Open tasks of the view not yet clarified: no priority, no estimate and no project, in capture order.
  public var inbox: [TaskItem] {
    openTasks.filter { !$0.isClarified }
  }

  /// Projects of the view that are nested in none, in creation order.
  public var topLevelProjects: [Project] {
    projects.filter { $0.parentID == nil }
  }

  /// The open tasks of the view with one of these priorities, the most urgent priority first and each in
  /// capture order. `nil` stands for no priority, listed last. An empty set lists nothing.
  public func tasks(prioritised priorities: Set<Priority?>) -> [TaskItem] {
    (Priority.allCases.map { Optional($0) } + [nil]).filter(priorities.contains).flatMap { priority in
      openTasks.filter { $0.priority == priority }
    }
  }

  /// The active sub-projects of a project, in the order they were added to it.
  public func subprojects(of projectID: ProjectID) -> [Project] {
    guard let parent = project(projectID) else { return [] }
    return parent.children.compactMap { child in
      guard case .project(let id) = child else { return nil }
      return project(id)
    }
  }

  /// The tasks of a project's subtree that the project hands out, as if it had no parent. Parallel: every
  /// child is active, a sub-project with its own next actions. Sequential: only the first child is.
  public func nextActions(of projectID: ProjectID) -> [TaskItem] {
    guard let project = self.project(projectID) else { return [] }
    let active =
      switch project.kind {
      case .parallel: project.children
      case .sequential: Array(project.children.prefix(1))
      }
    return active.flatMap { child -> [TaskItem] in
      switch child {
      // A someday task is kept out of next actions until it is promoted to another priority.
      case .task(let task): task.priority == .someday ? [] : [task]
      case .project(let id): nextActions(of: id)
      }
    }
  }

  /// The tasks of the view's projects that can be worked on now: every ancestor lets them be.
  public var nextActions: [TaskItem] {
    topLevelProjects.flatMap { nextActions(of: $0.id) }
  }

  private func project(_ projectID: ProjectID) -> Project? {
    projects.first { $0.id == projectID }
  }
}
