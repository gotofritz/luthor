public struct TaskItem: Equatable, Sendable {
  public let id: TaskID
  public let title: String
  /// The project the task is filed in; `nil` while it is in the inbox.
  public let projectID: ProjectID?

  public init(id: TaskID, title: String, projectID: ProjectID? = nil) {
    self.id = id
    self.title = title
    self.projectID = projectID
  }
}

public struct Project: Equatable, Sendable {
  public let id: ProjectID
  public let title: String
  public let kind: ProjectKind
  /// Open tasks in the order they were filed.
  public fileprivate(set) var tasks: [TaskItem]

  public init(id: ProjectID, title: String, kind: ProjectKind, tasks: [TaskItem] = []) {
    self.id = id
    self.title = title
    self.kind = kind
    self.tasks = tasks
  }

  /// The tasks that can be worked on now: every open task of a parallel project, the first of a
  /// sequential one.
  public var nextActions: [TaskItem] {
    switch kind {
    case .parallel: tasks
    case .sequential: Array(tasks.prefix(1))
    }
  }
}

public struct LibraryState: Equatable, Sendable {
  /// Every open task, in the inbox or in a project, in capture order.
  public private(set) var openTasks: [TaskItem] = []
  /// Active projects in creation order.
  public private(set) var projects: [Project] = []

  /// Open tasks not yet filed into a project, in capture order.
  public var inbox: [TaskItem] {
    openTasks.filter { $0.projectID == nil }
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
      openTasks.append(TaskItem(id: captured.taskID, title: captured.title))
    case .taskCompleted(let completed):
      openTasks.removeAll { $0.id == completed.taskID }
      removeFromProjects(completed.taskID)
    case .projectCreated(let created):
      guard !projects.contains(where: { $0.id == created.projectID }) else { return }
      projects.append(Project(id: created.projectID, title: created.title, kind: created.kind))
    case .taskMovedToProject(let moved):
      move(moved.taskID, to: moved.projectID)
    case .projectCompleted(let completed):
      openTasks.removeAll { $0.projectID == completed.projectID }
      projects.removeAll { $0.id == completed.projectID }
    }
  }

  /// Ignores a task that is not open, a project that is not active, and a task already in the project.
  private mutating func move(_ taskID: TaskID, to projectID: ProjectID) {
    guard let index = openTasks.firstIndex(where: { $0.id == taskID }),
      let target = projects.firstIndex(where: { $0.id == projectID }),
      openTasks[index].projectID != projectID
    else { return }
    let filed = TaskItem(id: taskID, title: openTasks[index].title, projectID: projectID)
    openTasks[index] = filed
    removeFromProjects(taskID)
    projects[target].tasks.append(filed)
  }

  private mutating func removeFromProjects(_ taskID: TaskID) {
    for index in projects.indices {
      projects[index].tasks.removeAll { $0.id == taskID }
    }
  }
}
