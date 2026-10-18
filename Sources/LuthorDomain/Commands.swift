/// Source of unique IDs for new events and tasks. Injected so tests stay deterministic.
public protocol IDGenerator {
  func next() -> String
}

public enum CommandError: Error, Equatable {
  case blankTitle
  case noOpenTask(String)
  case noActiveProject(ProjectID)
  /// The task is open, or was completed along with its project, so it cannot be reopened on its own.
  case noCompletedTask(TaskID)
  /// The project is active, or was completed along with another, so it cannot be reopened on its own.
  case noCompletedProject(ProjectID)
  case noView(ViewID)
  case duplicateViewName(String)
  /// The task and the project are in different views; only a move to the view takes a task across.
  case otherView(TaskID, ProjectID)
  /// The project and the one it would be nested in are in different views.
  case projectInOtherView(ProjectID, parent: ProjectID)
  /// A project cannot be nested under itself or one of its own sub-projects.
  case nestedUnderItself(ProjectID)
  /// A someday task is not committed to; give it another priority before planning it for a day.
  case someday(TaskID)
  /// The task is neither open nor completed: it never existed, or it was dropped.
  case unknownTask(TaskID)
  case noTag(TagID)
  /// A view has a tag with this name already, in any case.
  case duplicateTagName(String)
  /// The task and the tag are in different views; a tag belongs to one view.
  case tagInOtherView(TaskID, TagID)
  /// The project was dropped, so it is not reviewed.
  case projectDropped(ProjectID)
}

/// Turns user intentions into new events, given the current log.
public struct Commands {
  let deviceID: DeviceID
  let ids: any IDGenerator

  public init(deviceID: DeviceID, ids: any IDGenerator) {
    self.deviceID = deviceID
    self.ids = ids
  }

  /// Captures a task into the inbox of the view `viewID`. `title` may carry the quick-capture syntax
  /// (`call bank !a 15m`); its priority and estimate land on the task, same as setting them by hand.
  /// `today` is the day it is, recorded as the day the task was created.
  public func capture(
    title: String,
    in viewID: ViewID,
    today: CalendarDate? = nil,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    try requireView(viewID, in: LibraryState.replay(log))
    return try captureEvents(title: title, viewID: viewID, today: today, log: log).events
  }

  /// Captures a task straight into the active project `projectID`, in the project's view. `title` may
  /// carry the quick-capture syntax, as `capture(title:in:log:)` does.
  public func capture(
    title: String,
    into projectID: ProjectID,
    today: CalendarDate? = nil,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let project = try activeProject(projectID, in: LibraryState.replay(log))
    let (events, taskID) = try captureEvents(title: title, viewID: project.viewID, today: today, log: log)
    return try events + move(taskID: taskID, to: projectID, log: log + events)
  }

  /// Completes the open task with exactly this ID.
  public func complete(taskID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    guard LibraryState.replay(log).openTasks.contains(where: { $0.id == taskID }) else {
      throw .noOpenTask(taskID.rawValue)
    }
    return [envelope(EventID(ids.next()), .taskCompleted(TaskCompleted(taskID: taskID)), log: log)]
  }

  /// Creates a project in the view `viewID`; `today` is recorded as the day it was created.
  public func createProject(
    title: String,
    kind: ProjectKind,
    in viewID: ViewID,
    today: CalendarDate? = nil,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let title = try Self.named(title)
    try requireView(viewID, in: LibraryState.replay(log))
    let eventID = EventID(ids.next())
    let created = ProjectCreated(
      projectID: ProjectID(ids.next()), title: title, kind: kind, viewID: viewID, createdOn: today)
    return [envelope(eventID, .projectCreated(created), log: log)]
  }

  /// Creates a project inside the active project `parentID`, in the parent's view.
  public func createProject(
    title: String,
    kind: ProjectKind,
    under parentID: ProjectID,
    today: CalendarDate? = nil,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let title = try Self.named(title)
    let parent = try activeProject(parentID, in: LibraryState.replay(log))
    let eventID = EventID(ids.next())
    let created = ProjectCreated(
      projectID: ProjectID(ids.next()), title: title, kind: kind, viewID: parent.viewID, parentID: parentID,
      createdOn: today)
    return [envelope(eventID, .projectCreated(created), log: log)]
  }

  /// Nests the active project `projectID` in the active project `parentID` of its view; with no parent,
  /// makes it top-level. Nesting a project where it already is writes nothing.
  public func move(
    projectID: ProjectID,
    under parentID: ProjectID?,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    let project = try activeProject(projectID, in: state)
    if let parentID {
      let parent = try activeProject(parentID, in: state)
      guard parent.viewID == project.viewID else { throw .projectInOtherView(projectID, parent: parentID) }
      guard !state.subtree(of: projectID).contains(parentID) else { throw .nestedUnderItself(projectID) }
    }
    guard project.parentID != parentID else { return [] }
    let moved = ProjectMovedToProject(projectID: projectID, parentID: parentID)
    return [envelope(EventID(ids.next()), .projectMovedToProject(moved), log: log)]
  }

  public func createView(name: String, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    let name = try Self.named(name)
    try requireUnique(name, in: LibraryState.replay(log))
    let eventID = EventID(ids.next())
    return [envelope(eventID, .viewCreated(ViewCreated(viewID: ViewID(ids.next()), name: name)), log: log)]
  }

  public func renameView(_ viewID: ViewID, to name: String, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let name = try Self.named(name)
    let state = LibraryState.replay(log)
    try requireView(viewID, in: state)
    try requireUnique(name, except: viewID, in: state)
    return [envelope(EventID(ids.next()), .viewRenamed(ViewRenamed(viewID: viewID, name: name)), log: log)]
  }

  /// Takes the open task `taskID` across to the view `viewID`, into its inbox. Moving a task into the
  /// view it is in writes nothing.
  public func move(taskID: TaskID, toView viewID: ViewID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope]
  {
    let state = LibraryState.replay(log)
    guard let task = state.openTasks.first(where: { $0.id == taskID }) else { throw .noOpenTask(taskID.rawValue) }
    try requireView(viewID, in: state)
    guard task.viewID != viewID else { return [] }
    return [envelope(EventID(ids.next()), .taskMovedToView(TaskMovedToView(taskID: taskID, viewID: viewID)), log: log)]
  }

  /// Takes the active project `projectID` and its open tasks across to the view `viewID`. Moving a
  /// project into the view it is in writes nothing.
  public func move(
    projectID: ProjectID,
    toView viewID: ViewID,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    let project = try activeProject(projectID, in: state)
    try requireView(viewID, in: state)
    guard project.viewID != viewID else { return [] }
    let moved = ProjectMovedToView(projectID: projectID, viewID: viewID)
    return [envelope(EventID(ids.next()), .projectMovedToView(moved), log: log)]
  }

  /// Files the open task `taskID` into the active project `projectID`, which must be in the task's view.
  /// Filing a task where it already is writes nothing.
  public func move(
    taskID: TaskID,
    to projectID: ProjectID,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    guard let task = state.openTasks.first(where: { $0.id == taskID }) else { throw .noOpenTask(taskID.rawValue) }
    let project = try activeProject(projectID, in: state)
    guard task.viewID == project.viewID else { throw .otherView(taskID, projectID) }
    guard task.projectID != projectID else { return [] }
    let moved = TaskMovedToProject(taskID: taskID, projectID: projectID)
    return [envelope(EventID(ids.next()), .taskMovedToProject(moved), log: log)]
  }

  /// Gives the open task `taskID` a priority, or with `nil` clears it. Giving a task the priority it has
  /// writes nothing.
  public func prioritize(taskID: TaskID, as priority: Priority?, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    guard let task = LibraryState.replay(log).openTasks.first(where: { $0.id == taskID }) else {
      throw .noOpenTask(taskID.rawValue)
    }
    guard task.priority != priority else { return [] }
    let prioritized = TaskPrioritized(taskID: taskID, priority: priority)
    return [envelope(EventID(ids.next()), .taskPrioritized(prioritized), log: log)]
  }

  /// Gives the open task `taskID` an estimate in minutes, or with `nil` clears it. Giving a task the
  /// estimate it has writes nothing.
  public func estimate(taskID: TaskID, as minutes: Int?, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    guard let task = LibraryState.replay(log).openTasks.first(where: { $0.id == taskID }) else {
      throw .noOpenTask(taskID.rawValue)
    }
    guard task.estimate != minutes else { return [] }
    let estimated = TaskEstimated(taskID: taskID, minutes: minutes)
    return [envelope(EventID(ids.next()), .taskEstimated(estimated), log: log)]
  }

  /// Changes a global setting, or with `nil` clears it back to the built-in default. Setting it to the
  /// value it already has writes nothing.
  public func changeSetting(_ key: SettingKey, to value: String?, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    guard LibraryState.replay(log).globalSettingValue(key) != value else { return [] }
    let changed = SettingChanged(key: key, value: value)
    return [envelope(EventID(ids.next()), .settingChanged(changed), log: log)]
  }

  /// Overrides a setting for the view `viewID`, or with `nil` clears the override back to the global
  /// value. Setting it to the value it already has writes nothing.
  public func changeSetting(
    _ key: SettingKey,
    to value: String?,
    for viewID: ViewID,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    try requireView(viewID, in: state)
    guard state.overrideValue(key, in: viewID) != value else { return [] }
    let changed = SettingChanged(key: key, value: value, viewID: viewID)
    return [envelope(EventID(ids.next()), .settingChanged(changed), log: log)]
  }

  /// Sets the default view; nothing reads it since the CLI was removed. The view must exist.
  public func setDefaultView(_ viewID: ViewID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    try requireView(viewID, in: LibraryState.replay(log))
    return try changeSetting(.defaultViewID, to: viewID.rawValue, log: log)
  }

  public func completeProject(_ projectID: ProjectID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    try requireActive(projectID, log: log)
    return [envelope(EventID(ids.next()), .projectCompleted(ProjectCompleted(projectID: projectID)), log: log)]
  }

  private func requireActive(_ projectID: ProjectID, log: [EventEnvelope]) throws(CommandError) {
    _ = try activeProject(projectID, in: LibraryState.replay(log))
  }

  func activeProject(_ projectID: ProjectID, in state: LibraryState) throws(CommandError) -> Project {
    guard let project = state.projects.first(where: { $0.id == projectID }) else { throw .noActiveProject(projectID) }
    return project
  }

  func requireView(_ viewID: ViewID, in state: LibraryState) throws(CommandError) {
    guard state.hasView(viewID) else { throw .noView(viewID) }
  }

  /// Throws unless no view but `viewID` has this name, in any case.
  private func requireUnique(_ name: String, except viewID: ViewID? = nil, in state: LibraryState) throws(CommandError)
  {
    if let existing = state.view(named: name), existing.id != viewID { throw .duplicateViewName(name) }
  }

  /// Captures `raw` (parsed for its quick-capture tags) into `viewID`, with a `TaskPrioritized` and/or a
  /// `TaskEstimated` event appended when the tags carry one.
  private func captureEvents(
    title raw: String,
    viewID: ViewID,
    today: CalendarDate?,
    log: [EventEnvelope]
  ) throws(CommandError) -> (events: [EventEnvelope], taskID: TaskID) {
    let parsed = QuickCapture.parse(raw)
    let title = try Self.named(parsed.title)
    let eventID = EventID(ids.next())
    let taskID = TaskID(ids.next())
    let captured = TaskCaptured(taskID: taskID, title: title, viewID: viewID, createdOn: today)
    var events = [envelope(eventID, .taskCaptured(captured), log: log)]
    if let priority = parsed.priority {
      events += try prioritize(taskID: taskID, as: priority, log: log + events)
    }
    if let minutes = parsed.estimateMinutes {
      events += try estimate(taskID: taskID, as: minutes, log: log + events)
    }
    return (events, taskID)
  }

  /// The title or name without surrounding whitespace; throws if nothing is left.
  static func named(_ title: String) throws(CommandError) -> String {
    let trimmed = trimmed(title)
    guard !trimmed.isEmpty else { throw .blankTitle }
    return trimmed
  }

  /// The text without surrounding whitespace.
  static func trimmed(_ text: String) -> String {
    String(text.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
  }

  func envelope(_ id: EventID, _ payload: EventPayload, log: [EventEnvelope]) -> EventEnvelope {
    EventEnvelope(id: id, deviceID: deviceID, lamport: (log.map(\.lamport).max() ?? 0) + 1, payload: payload)
  }
}
