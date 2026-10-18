/// What a project holds: an open task, or an open sub-project.
public enum ProjectChild: Equatable, Sendable {
  case task(TaskItem)
  case project(TaskID)
}

/// An item that holds others, as a view of one lists it.
public struct Project: Equatable, Sendable {
  public let id: TaskID
  public internal(set) var title: String
  public internal(set) var kind: ProjectKind
  public internal(set) var viewID: ViewID
  /// The project it is nested in; `nil` for a top-level project.
  public internal(set) var parentID: TaskID?
  /// Open tasks and open sub-projects, in the order they were added to the project.
  public internal(set) var children: [ProjectChild]
  /// Plain-text notes; `nil` until it is given some.
  public internal(set) var notes: String?
  /// The day the project was created; `nil` for one created before cards showed it.
  public let createdOn: CalendarDate?
  /// Its own priority and estimate in minutes, as for a task; they are shown and not planned, and do not flow
  /// down to what it holds.
  public internal(set) var priority: Priority?
  public internal(set) var estimate: Int?

  public init(
    id: TaskID,
    title: String,
    kind: ProjectKind,
    viewID: ViewID,
    parentID: TaskID? = nil,
    children: [ProjectChild] = [],
    notes: String? = nil,
    createdOn: CalendarDate? = nil,
    priority: Priority? = nil,
    estimate: Int? = nil
  ) {
    self.id = id
    self.title = title
    self.kind = kind
    self.viewID = viewID
    self.parentID = parentID
    self.children = children
    self.notes = notes
    self.createdOn = createdOn
    self.priority = priority
    self.estimate = estimate
  }

  /// Open tasks filed straight into the project, in the order they were filed.
  public var tasks: [TaskItem] {
    children.compactMap { child in
      guard case .task(let task) = child else { return nil }
      return task
    }
  }
}
