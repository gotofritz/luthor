import LuthorDomain

/// What the sidebar can show: the inbox or one active project.
public enum SidebarItem: Hashable, Sendable {
  case inbox
  case project(ProjectID)
}

/// The places the navigation rail leads to, in the order it lists them.
public enum NavigationSection: Hashable, Sendable, CaseIterable {
  case inbox
  case today
  case review
  case projects
  case priorities
  case settings
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
