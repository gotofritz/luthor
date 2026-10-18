/// Whether a project is handing out next actions. On-hold and dropped projects hand out none, and a dropped one
/// is not reviewed.
public enum ProjectStatus: String, Codable, Sendable {
  case active
  case onHold
  case dropped
}

/// What a project holds: an open task, or an active sub-project.
public enum ProjectChild: Equatable, Sendable {
  case task(TaskItem)
  case project(ProjectID)
}

public struct Project: Equatable, Sendable {
  public let id: ProjectID
  public internal(set) var title: String
  public internal(set) var kind: ProjectKind
  public internal(set) var viewID: ViewID
  /// The project it is nested in; `nil` for a top-level project.
  public internal(set) var parentID: ProjectID?
  /// Open tasks and active sub-projects, in the order they were added to the project.
  public internal(set) var children: [ProjectChild]
  /// Plain-text notes; `nil` until it is given some.
  public internal(set) var notes: String?
  /// The day the project was created; `nil` for one created before cards showed it.
  public let createdOn: CalendarDate?
  /// Whether the project is handing out next actions, is on hold, or was dropped.
  public internal(set) var status: ProjectStatus

  public init(
    id: ProjectID,
    title: String,
    kind: ProjectKind,
    viewID: ViewID,
    parentID: ProjectID? = nil,
    children: [ProjectChild] = [],
    notes: String? = nil,
    createdOn: CalendarDate? = nil,
    status: ProjectStatus = .active
  ) {
    self.id = id
    self.title = title
    self.kind = kind
    self.viewID = viewID
    self.parentID = parentID
    self.children = children
    self.notes = notes
    self.createdOn = createdOn
    self.status = status
  }

  /// Open tasks filed straight into the project, in the order they were filed.
  public var tasks: [TaskItem] {
    children.compactMap { child in
      guard case .task(let task) = child else { return nil }
      return task
    }
  }
}
