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
  /// How much the task matters; `nil` until it is given one.
  public let priority: Priority?
  /// Minutes the task is expected to take; `nil` until it is given one.
  public let estimate: Int?

  public init(
    id: TaskID,
    title: String,
    viewID: ViewID,
    projectID: ProjectID? = nil,
    priority: Priority? = nil,
    estimate: Int? = nil
  ) {
    self.id = id
    self.title = title
    self.viewID = viewID
    self.projectID = projectID
    self.priority = priority
    self.estimate = estimate
  }

  /// Not yet clarified: no priority, no estimate and no project.
  var isClarified: Bool {
    priority != nil || estimate != nil || projectID != nil
  }

  fileprivate func prioritized(_ priority: Priority?) -> TaskItem {
    TaskItem(id: id, title: title, viewID: viewID, projectID: projectID, priority: priority, estimate: estimate)
  }

  fileprivate func estimated(_ estimate: Int?) -> TaskItem {
    TaskItem(id: id, title: title, viewID: viewID, projectID: projectID, priority: priority, estimate: estimate)
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

/// The state of every view. Tasks and projects are reachable only through `view(_:)`, which names the
/// view: isolation between views is a rule of the domain, not a filter in the UI.
public struct LibraryState: Equatable, Sendable {
  /// The default view, then the others in creation order.
  public private(set) var views = [ViewItem(id: .default, name: "Default")]
  /// Every open task of every view, in capture order.
  private(set) var openTasks: [TaskItem] = []
  /// Every active project of every view, in creation order.
  private(set) var projects: [Project] = []
  /// Global setting values, by key; a key not here falls back to its built-in default.
  var globalSettingValues: [SettingKey: String] = [:]
  /// Per-view setting overrides; a key not here for a view falls back to the global value.
  var viewSettingOverrides: [ViewID: [SettingKey: String]] = [:]
  /// The day each open task is planned for; a task not here is planned for no day.
  var scheduledDates: [TaskID: CalendarDate] = [:]
  /// The open tasks handed to someone else.
  var delegations: [TaskID: Delegation] = [:]
  /// The manual order of each view's plan for a day, as last set.
  var dayOrders: [DayKey: [TaskID]] = [:]
  /// The capacity set for single days, in place of the weekday's.
  var dayCapacities: [DayKey: Int] = [:]

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
      finish(completed.taskID)
    case .projectCreated(let created):
      create(created)
    case .taskMovedToProject(let moved):
      move(moved.taskID, to: moved.projectID)
    case .projectCompleted(let completed):
      complete(completed.projectID)
    case .viewCreated(let created):
      create(created)
    case .viewRenamed(let renamed):
      rename(renamed)
    case .taskMovedToView(let moved):
      move(moved.taskID, toView: moved.viewID)
    case .projectMovedToView(let moved):
      move(moved.projectID, toView: moved.viewID)
    case .projectMovedToProject(let moved):
      nest(moved.projectID, under: moved.parentID)
    case .taskPrioritized(let prioritized):
      prioritize(prioritized.taskID, as: prioritized.priority)
    case .taskEstimated(let estimated):
      estimate(estimated.taskID, as: estimated.minutes)
    case .settingChanged(let changed):
      change(changed)
    case .taskScheduled(let scheduled):
      schedule(scheduled)
    case .taskUnscheduled(let unscheduled):
      scheduledDates.removeValue(forKey: unscheduled.taskID)
    case .dayPlanOrdered(let ordered):
      order(ordered)
    case .dayCapacitySet(let capacity):
      setCapacity(capacity)
    case .taskDelegated(let delegated):
      delegate(delegated)
    case .taskReclaimed(let reclaimed):
      delegations.removeValue(forKey: reclaimed.taskID)
    case .taskDropped(let dropped):
      finish(dropped.taskID)
    }
  }

  /// Takes a task out of every list for good, completed or dropped. Ignores a task that is not open.
  private mutating func finish(_ taskID: TaskID) {
    openTasks.removeAll { $0.id == taskID }
    removeFromProjects(taskID)
    forgetPlanning(of: taskID)
  }

  func hasView(_ viewID: ViewID) -> Bool {
    views.contains { $0.id == viewID }
  }

  /// Ignores a project that already exists. Under a parent that is not active or is in another view, the
  /// project is top-level.
  private mutating func create(_ created: ProjectCreated) {
    guard !projects.contains(where: { $0.id == created.projectID }) else { return }
    let parent = created.parentID.flatMap { parentID in
      projects.firstIndex { $0.id == parentID && $0.viewID == created.viewID }
    }
    projects.append(
      Project(
        id: created.projectID, title: created.title, kind: created.kind, viewID: created.viewID,
        parentID: parent.map { projects[$0].id }))
    if let parent { projects[parent].children.append(.project(created.projectID)) }
  }

  /// Completes a project with its open tasks and sub-projects, all the way down. Ignores a project that is
  /// not active.
  private mutating func complete(_ projectID: ProjectID) {
    let completed = subtree(of: projectID)
    detach(projectID)
    openTasks.removeAll { task in task.projectID.map { completed.contains($0) } ?? false }
    projects.removeAll { completed.contains($0.id) }
  }

  /// Nests a project under another of its view, or with no parent makes it top-level, at the end of its new
  /// parent's children. Ignores a project or parent that is not active, a parent in another view, a parent
  /// in the project's own subtree, and a project already there.
  private mutating func nest(_ projectID: ProjectID, under parentID: ProjectID?) {
    guard let index = projects.firstIndex(where: { $0.id == projectID }),
      projects[index].parentID != parentID
    else { return }
    if let parentID {
      guard let parent = projects.firstIndex(where: { $0.id == parentID }),
        projects[parent].viewID == projects[index].viewID,
        !subtree(of: projectID).contains(parentID)
      else { return }
      detach(projectID)
      projects[index].parentID = parentID
      projects[parent].children.append(.project(projectID))
    } else {
      detach(projectID)
    }
  }

  /// The project and every active project nested in it, at any depth; empty for a project that is not
  /// active.
  func subtree(of projectID: ProjectID) -> Set<ProjectID> {
    guard let project = projects.first(where: { $0.id == projectID }) else { return [] }
    var found: Set<ProjectID> = [projectID]
    for case .project(let child) in project.children {
      found.formUnion(subtree(of: child))
    }
    return found
  }

  /// Takes a project out of its parent's children, making it top-level.
  private mutating func detach(_ projectID: ProjectID) {
    guard let index = projects.firstIndex(where: { $0.id == projectID }),
      let parentID = projects[index].parentID
    else { return }
    projects[index].parentID = nil
    guard let parent = projects.firstIndex(where: { $0.id == parentID }) else { return }
    projects[parent].children.removeAll { $0 == .project(projectID) }
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
    let filed = TaskItem(
      id: taskID, title: task.title, viewID: task.viewID, projectID: projectID, priority: task.priority,
      estimate: task.estimate)
    openTasks[index] = filed
    removeFromProjects(taskID)
    projects[target].children.append(.task(filed))
  }

  /// Ignores a task that is not open and a view that does not exist.
  private mutating func move(_ taskID: TaskID, toView viewID: ViewID) {
    guard let index = openTasks.firstIndex(where: { $0.id == taskID }), hasView(viewID) else { return }
    let task = openTasks[index]
    openTasks[index] = TaskItem(
      id: taskID, title: task.title, viewID: viewID, priority: task.priority, estimate: task.estimate)
    removeFromProjects(taskID)
    forgetPlanning(of: taskID)
  }

  /// Takes a project across with its sub-projects and their open tasks; a nested project leaves its
  /// parent and is top-level there. Ignores a project that is not active and a view that does not exist.
  private mutating func move(_ projectID: ProjectID, toView viewID: ViewID) {
    guard projects.contains(where: { $0.id == projectID }), hasView(viewID) else { return }
    let moved = subtree(of: projectID)
    let reassign = { (task: TaskItem) in
      TaskItem(
        id: task.id, title: task.title, viewID: viewID, projectID: task.projectID, priority: task.priority,
        estimate: task.estimate)
    }
    detach(projectID)
    openTasks = openTasks.map { task in
      let isMoved = task.projectID.map { moved.contains($0) } ?? false
      return isMoved ? reassign(task) : task
    }
    for index in projects.indices where moved.contains(projects[index].id) {
      projects[index].viewID = viewID
      projects[index].children = projects[index].children.map { child in
        guard case .task(let task) = child else { return child }
        return .task(reassign(task))
      }
    }
  }

  /// Ignores a task that is not open.
  private mutating func prioritize(_ taskID: TaskID, as priority: Priority?) {
    updateTask(taskID) { $0.prioritized(priority) }
  }

  /// Ignores a task that is not open.
  private mutating func estimate(_ taskID: TaskID, as minutes: Int?) {
    updateTask(taskID) { $0.estimated(minutes) }
  }

  /// Replaces the open task `taskID`, wherever it is filed, with the result of `transform`. Ignores a
  /// task that is not open.
  private mutating func updateTask(_ taskID: TaskID, _ transform: (TaskItem) -> TaskItem) {
    guard let index = openTasks.firstIndex(where: { $0.id == taskID }) else { return }
    openTasks[index] = transform(openTasks[index])
    for project in projects.indices {
      projects[project].children = projects[project].children.map { child in
        guard case .task(let task) = child, task.id == taskID else { return child }
        return .task(transform(task))
      }
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
