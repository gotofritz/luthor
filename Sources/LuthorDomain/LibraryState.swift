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
  public internal(set) var title: String
  public internal(set) var viewID: ViewID
  /// The project the task is filed in; `nil` while it is in the inbox.
  public internal(set) var projectID: ProjectID?
  /// How much the task matters; `nil` until it is given one.
  public internal(set) var priority: Priority?
  /// Minutes the task is expected to take; `nil` until it is given one.
  public internal(set) var estimate: Int?
  /// Plain-text notes; `nil` until it is given some.
  public internal(set) var notes: String?
  /// The day the task was captured; `nil` for one captured before cards showed it.
  public let createdOn: CalendarDate?

  public init(
    id: TaskID,
    title: String,
    viewID: ViewID,
    projectID: ProjectID? = nil,
    priority: Priority? = nil,
    estimate: Int? = nil,
    notes: String? = nil,
    createdOn: CalendarDate? = nil
  ) {
    self.id = id
    self.title = title
    self.viewID = viewID
    self.projectID = projectID
    self.priority = priority
    self.estimate = estimate
    self.notes = notes
    self.createdOn = createdOn
  }

  /// Not yet clarified: no priority, no estimate and no project.
  var isClarified: Bool {
    priority != nil || estimate != nil || projectID != nil
  }
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

  public init(
    id: ProjectID,
    title: String,
    kind: ProjectKind,
    viewID: ViewID,
    parentID: ProjectID? = nil,
    children: [ProjectChild] = [],
    notes: String? = nil,
    createdOn: CalendarDate? = nil
  ) {
    self.id = id
    self.title = title
    self.kind = kind
    self.viewID = viewID
    self.parentID = parentID
    self.children = children
    self.notes = notes
    self.createdOn = createdOn
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
  var openTasks: [TaskItem] = []
  /// Every active project of every view, in creation order.
  var projects: [Project] = []
  /// Every completed task of every view, in the order they were completed.
  var completedTasks: [Completed<TaskItem>] = []
  /// Every completed project of every view, a completed project before the sub-projects it took along.
  /// A completed project keeps the parent it had, though it is no longer in that parent's children.
  var completedProjects: [Completed<Project>] = []
  /// The position each task was captured at, so a reopened task goes back to its place among the open ones.
  var captureOrder: [TaskID: Int] = [:]
  /// Global setting values, by key; a key not here falls back to its built-in default.
  var globalSettingValues: [SettingKey: String] = [:]
  /// Per-view setting overrides; a key not here for a view falls back to the global value.
  var viewSettingOverrides: [ViewID: [SettingKey: String]] = [:]
  /// The day each open task is planned for; a task not here is planned for no day.
  var scheduledDates: [TaskID: CalendarDate] = [:]
  /// The open tasks handed to someone else.
  var delegations: [TaskID: Delegation] = [:]
  /// The due date of each task that has one. Completing a task keeps it, so reopening brings it back.
  var dueDates: [TaskID: DueDate] = [:]
  /// The manual order of each view's plan for a day, as last set.
  var dayOrders: [DayKey: [TaskID]] = [:]
  /// The capacity set for single days, in place of the weekday's.
  var dayCapacities: [DayKey: Int] = [:]
  /// What the daily review looks back on: logged time, reviewed days, and the day each completed task was
  /// planned for.
  var reviewRecords = ReviewRecords()

  /// The open tasks and active projects of one view; empty for a view that does not exist.
  public func view(_ viewID: ViewID) -> ViewState {
    ViewState(
      id: viewID,
      openTasks: openTasks.filter { $0.viewID == viewID },
      projects: projects.filter { $0.viewID == viewID },
      completedTasks: completedTasks.filter { $0.item.viewID == viewID },
      completedProjects: completedProjects.filter { $0.item.viewID == viewID }
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
      capture(captured)
    case .taskCompleted(let completed):
      complete(completed.taskID)
    case .taskReopened(let reopened):
      reopen(reopened.taskID)
    case .taskRenamed, .taskNoted, .projectRenamed, .projectNoted, .projectKindChanged:
      applyCardEdit(payload)
    case .projectReopened(let reopened):
      reopen(reopened.projectID)
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
    case .taskDelegated(let delegated):
      delegate(delegated)
    case .taskReclaimed(let reclaimed):
      delegations.removeValue(forKey: reclaimed.taskID)
    case .taskDropped(let dropped):
      finish(dropped.taskID)
    case .dayPlanOrdered, .dayCapacitySet, .taskDueSet:
      applyPlanning(payload)
    case .taskTimeLogged, .unplannedTimeLogged, .dayReviewed:
      applyReview(payload)
    }
  }

  /// Takes a task out of every list for good, completed or dropped. Ignores a task that is not open.
  mutating func finish(_ taskID: TaskID) {
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
        parentID: parent.map { projects[$0].id }, createdOn: created.createdOn))
    if let parent { projects[parent].children.append(.project(created.projectID)) }
  }

  /// Completes a project with its open tasks and sub-projects, all the way down. Ignores a project that is
  /// not active.
  private mutating func complete(_ projectID: ProjectID) {
    let completed = subtree(of: projectID)
    keepCompleted(projectID, subtree: completed)
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
    var filed = openTasks[index]
    filed.projectID = projectID
    openTasks[index] = filed
    removeFromProjects(taskID)
    projects[target].children.append(.task(filed))
  }

  /// Ignores a task that is not open and a view that does not exist.
  private mutating func move(_ taskID: TaskID, toView viewID: ViewID) {
    guard let index = openTasks.firstIndex(where: { $0.id == taskID }), hasView(viewID) else { return }
    openTasks[index].viewID = viewID
    openTasks[index].projectID = nil
    removeFromProjects(taskID)
    forgetPlanning(of: taskID)
  }

  /// Takes a project across with its sub-projects and their open tasks; a nested project leaves its
  /// parent and is top-level there. Ignores a project that is not active and a view that does not exist.
  private mutating func move(_ projectID: ProjectID, toView viewID: ViewID) {
    guard projects.contains(where: { $0.id == projectID }), hasView(viewID) else { return }
    let moved = subtree(of: projectID)
    let reassign = { (task: TaskItem) in
      var task = task
      task.viewID = viewID
      return task
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
    updateTask(taskID) { $0.priority = priority }
  }

  /// Ignores a task that is not open.
  private mutating func estimate(_ taskID: TaskID, as minutes: Int?) {
    updateTask(taskID) { $0.estimate = minutes }
  }

  /// Changes the open task `taskID`, wherever it is filed, with `change`. Ignores a task that is not open.
  mutating func updateTask(_ taskID: TaskID, _ change: (inout TaskItem) -> Void) {
    guard let index = openTasks.firstIndex(where: { $0.id == taskID }) else { return }
    change(&openTasks[index])
    for project in projects.indices {
      projects[project].children = projects[project].children.map { child in
        guard case .task(var task) = child, task.id == taskID else { return child }
        change(&task)
        return .task(task)
      }
    }
  }

  /// Changes the active project `projectID` with `change`. Ignores a project that is not active.
  mutating func updateProject(_ projectID: ProjectID, _ change: (inout Project) -> Void) {
    guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return }
    change(&projects[index])
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
