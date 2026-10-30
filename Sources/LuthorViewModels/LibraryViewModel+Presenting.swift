import LuthorDomain
import LuthorStore

// Internals: reading and writing the log, and filling the published state from it. Split from the
// class body (SwiftLint type_body_length and file_length) rather than suppressed.
extension LibraryViewModel {
  /// Applies `action` to the selected task; if that takes it off the list, selects the task that takes
  /// its place.
  func replaceSelected(_ action: (TaskID) -> Void) {
    guard let selected = selection, let position = index(of: selected) else { return }
    action(selected)
    guard !tasks.contains(where: { $0.id == selected }) else { return }
    selection = tasks.isEmpty ? nil : tasks[min(position, tasks.count - 1)].id
  }

  /// The commands, bound to the state held: a command is given no log, only the state it acts on, and costs what it
  /// changes. Anything that is handed a whole log uses `unboundCommands`.
  var commands: Commands { unboundCommands.after(state, lamport: lastLamport) }

  /// Reads from the state held for a view. `state` is not observed, so a read made straight from it leaves the view
  /// stale when the log changes; this one reads `revision` too, which every replay moves, so the view is told.
  func observing<Value>(_ read: (LibraryState) -> Value) -> Value {
    _ = revision
    return read(state)
  }

  /// The selected task, whose card is shown.
  public var selectedTask: TaskItem? {
    selection.flatMap { selected in tasks.first { $0.id == selected } }
  }

  /// Runs a command on the state held and appends what it returns, applying those events to the state; returns the
  /// events written. The command is given no log: `commands` knows the state. The log is read first only if its
  /// files changed since the state held was read, so events another process appended are never missed.
  ///
  /// Unless `recordsUndo` is off (as for an undo or redo itself), a command that can be taken back is kept for Undo.
  @discardableResult
  func perform(
    recordsUndo: Bool = true,
    _ command: ([EventEnvelope]) throws(CommandError) -> [EventEnvelope]
  ) -> [EventEnvelope] {
    if let token = log.changeToken(), token == loggedToken {
      // Nothing outside has written since.
    } else if !catchUpWithLog() {
      return []
    }
    let events: [EventEnvelope]
    do {
      events = try command([])
    } catch {
      // A blank title, a view name already taken, or a task completed elsewhere since the last reload:
      // nothing to write, and nothing the user needs to fix.
      showState()
      return []
    }
    do {
      try log.append(events)
    } catch {
      errorMessage = Self.describe(error)
      return []
    }
    let step = recordsUndo ? state.undoStep(for: events.map(\.payload)) : nil
    state.append(events)
    _ = held.add(events)
    lastLamport = events.reduce(lastLamport) { max($0, $1.lamport) }
    loggedToken = log.changeToken()
    if let step {
      undoSteps.append(step)
      redoSteps = []
    }
    showState()
    return events
  }

  /// Brings the state held up to the log as it is now; `false`, with `errorMessage` set, if it cannot be read.
  private func catchUpWithLog() -> Bool {
    do {
      _ = try readLog()
      return true
    } catch {
      errorMessage = Self.describe(error)
      return false
    }
  }

  func show(_ events: [EventEnvelope]) {
    state = LibraryState.replay(events)
    held = HeldLog(events)
    lastLamport = events.reduce(0) { max($0, $1.lamport) }
    undoSteps = []
    redoSteps = []
    showState()
  }

  /// Presents `state` as it is.
  func showState() {
    generation += 1
    revision += 1
    errorMessage = nil
    present()
  }

  /// Fills the view switcher, the sidebar and the list from the current view of the last replayed state.
  func present() {
    layouts.cached = nil
    pruneMultiSelection()
    views = state.views
    if !views.contains(where: { $0.id == currentView }) {
      // A remembered view this log does not have.
      currentView = .default
    }
    globalSettings = state.globalSettings
    viewSettings = state.settings(for: currentView)
    settingsByView = Dictionary(uniqueKeysWithValues: views.map { ($0.id, state.settings(for: $0.id)) })
    overriddenKeysByView = Dictionary(
      uniqueKeysWithValues: views.map { view in
        (view.id, Set(SettingKey.allCases.filter { state.isOverridden($0, in: view.id) }))
      })
    defaultViewID = state.defaultViewID
    let view = state.view(currentView)
    projects = view.projects
    let completed =
      showCompleted ? Completion(view, window: completedWindow, today: clock()) : Completion()
    let known = projects + completed.projects.map(\.item)
    knownProjects = known
    if let projectID = shownProjectID, !known.contains(where: { $0.id == projectID }) {
      // Completed here or elsewhere, with completed items hidden: there is nothing left to show.
      sidebarSelection = .inbox
    }
    path = shownProjectID.map { ancestry(of: $0, among: known) } ?? []
    shownProject = path.last.flatMap { id in known.first { $0.id == id } }
    columns = projectColumns(of: view, completed: completed)
    let previousToday = today
    today = clock()
    // The day shown as today moves on with it; a day looked at on purpose stays.
    if planDate == previousToday { planDate = today }
    // Each place is worked out only while it is shown, so an action elsewhere does not pay for it; going to a
    // place presents again.
    if section == .today || section == .review {
      plan = state.plan(for: currentView, on: planDate, today: today, matching: candidateFilter)
      waiting = state.waitingFor(in: currentView, today: today)
      carryOver = state.carryOver(in: currentView, today: today)
    }
    if section == .review { review = state.dayReview(for: currentView, on: planDate, today: today) }
    if section == .calendar { presentCalendar() }
    presentTags()
    presentProjectReview()
    presentTasks(of: view, completed: completed)
    presentCompletion(completed)
    if let selected = selection, index(of: selected) == nil { selection = nil }
  }

  /// The completed items listed beside the open ones; none while they are hidden.
  struct Completion {
    var tasks: [Completed<TaskItem>] = []
    var projects: [Completed<Project>] = []

    init() {}

    init(_ view: ViewState, window: CompletedWindow, today: CalendarDate) {
      tasks = view.completedTasks.filter { window.includes(completedOn: $0.completedOn, today: today) }
      projects = view.completedProjects.filter { window.includes(completedOn: $0.completedOn, today: today) }
    }

    /// The completed sub-projects, then the completed tasks, filed in a project; the top level has no
    /// tasks of its own.
    func entries(under parentID: TaskID?) -> [ColumnEntry] {
      let subprojects = projects.filter { $0.item.parentID == parentID }.map { ColumnEntry.project($0.item) }
      guard let parentID else { return subprojects }
      return subprojects + tasks.filter { $0.item.parentID == parentID }.map { .task($0.item) }
    }
  }

  /// The top-level projects, then one column for each project on the path.
  private func projectColumns(of view: ViewState, completed: Completion) -> [ProjectColumn] {
    let top = view.topLevelProjects.map { ColumnEntry.project($0) } + completed.entries(under: nil)
    var columns = [ProjectColumn(parentID: nil, entries: sorted(top, inList: "top"))]
    for projectID in path {
      let open = projects.first { $0.id == projectID }?.children.compactMap { entry($0) } ?? []
      let listed = open + completed.entries(under: projectID)
      columns.append(
        ProjectColumn(parentID: projectID, entries: sorted(listed, inList: "project-\(projectID.rawValue)")))
    }
    return columns
  }

  /// Marks which of the tasks and projects listed are completed, and which of those can be reopened.
  private func presentCompletion(_ completed: Completion) {
    let listed = Set(tasks.map(\.id)).union(
      columns.flatMap(\.entries).compactMap { entry -> TaskID? in
        guard case .task(let task) = entry else { return nil }
        return task.id
      })
    let listedProjects = Set(
      columns.flatMap(\.entries).compactMap { entry -> TaskID? in
        guard case .project(let project) = entry else { return nil }
        return project.id
      })
    let tasksShown = completed.tasks.filter { listed.contains($0.item.id) }
    let projectsShown = completed.projects.filter { listedProjects.contains($0.item.id) }
    completedTaskIDs = Set(tasksShown.map(\.item.id))
    completedProjectIDs = Set(projectsShown.map(\.item.id))
    droppedTaskIDs = Set(tasksShown.filter(\.isDropped).map(\.item.id))
    droppedProjectIDs = Set(projectsShown.filter(\.isDropped).map(\.item.id))
    reopenableTaskIDs = Set(tasksShown.filter(\.isReopenable).map(\.item.id))
    reopenableProjectIDs = Set(projectsShown.filter(\.isReopenable).map(\.item.id))
  }

  /// Fills the list of the place the rail has picked: the leftovers, the plan and its candidates, the tasks
  /// not done on the day reviewed, the tasks of the project picked in the weekly review, the tasks of the day
  /// picked on the calendar, the tasks with a priority picked, the tasks with the tag picked, the project
  /// shown, or the inbox; completed tasks follow the open ones.
  private func presentTasks(of view: ViewState, completed: Completion) {
    let completedItems = completed.tasks.map(\.item)
    var listed: [TaskItem]
    var actionable: Set<TaskID>
    switch section {
    case .today:
      listed = (carryOver.map(\.entry) + plan.entries + plan.candidates).map(\.task)
      actionable = Set(listed.map(\.id))
    case .review:
      listed = review.notDone.map(\.task)
      actionable = Set(listed.map(\.id))
    case .weeklyReview:
      listed = projectReview.first { $0.project.id == reviewProjectID }?.project.tasks ?? []
      actionable = Set(view.nextActions.map(\.id)).intersection(listed.map(\.id))
    case .calendar:
      listed = calendarEntries.map(\.task)
      actionable = Set(listed.map(\.id))
    case .priorities:
      listed =
        view.tasks(prioritised: selectedPriorities)
        + completedItems.filter { selectedPriorities.contains($0.priority) }
      let next = Set(view.nextActions.map(\.id))
      actionable = Set(listed.filter { $0.parentID == nil || next.contains($0.id) }.map(\.id))
    case .tags:
      listed = selectedTagID.map { state.tasks(tagged: $0) } ?? []
      let next = Set(view.nextActions.map(\.id))
      actionable = Set(listed.filter { $0.parentID == nil || next.contains($0.id) }.map(\.id))
    case .inbox, .projects, .settings:
      if let projectID = shownProjectID {
        listed =
          (projects.first { $0.id == projectID }?.tasks ?? []) + completedItems.filter { $0.parentID == projectID }
        let shown = columns.flatMap(\.entries).compactMap { entry -> TaskID? in
          guard case .task(let task) = entry else { return nil }
          return task.id
        }
        actionable = Set(view.nextActions.map(\.id)).intersection(shown)
      } else {
        listed = view.inbox + completedItems.filter { $0.parentID == nil }
        actionable = Set(view.inbox.map(\.id))
      }
    }
    if section == .inbox || section == .tags || section == .weeklyReview { listed = sorted(listed) }
    tasks = listed
    nextActions = actionable
  }

  /// The project and its ancestors, top-level first.
  private func ancestry(of projectID: TaskID, among known: [Project]) -> [TaskID] {
    var path: [TaskID] = []
    var current: TaskID? = projectID
    while let id = current, !path.contains(id), let project = known.first(where: { $0.id == id }) {
      path.insert(id, at: 0)
      current = project.parentID
    }
    return path
  }

  /// A child as a column shows it; `nil` for a sub-project that is not in the view.
  private func entry(_ child: ProjectChild) -> ColumnEntry? {
    switch child {
    case .task(let task):
      return .task(task)
    case .project(let projectID):
      guard let project = projects.first(where: { $0.id == projectID }) else { return nil }
      return .project(project)
    }
  }

  var shownProjectID: TaskID? {
    guard case .project(let projectID) = sidebarSelection else { return nil }
    return projectID
  }

  func index(of taskID: TaskID) -> Int? {
    tasks.firstIndex { $0.id == taskID }
  }

  static func describe(_ error: EventLogError) -> String {
    switch error {
    case .unreadableLine(let number): "Line \(number) of the event log is not a readable event."
    case .ioFailure(let message): message
    }
  }
}

// Text export and import of the tasks and projects.
extension LibraryViewModel {
  /// Every view, tag, task and project as YAML text, or `nil` with `errorMessage` set when the log cannot be
  /// read.
  public func exportText() -> String? {
    do {
      return try LibraryText.export(LibraryState.replay(try log.readAll()).export())
    } catch {
      errorMessage = Self.describe(error)
      return nil
    }
  }

  /// Adds the views, tags, tasks and projects of an export that the library does not have yet; importing a
  /// text twice adds nothing.
  public func importText(_ text: String) {
    do {
      let library = try LibraryText.library(from: text)
      let current = try log.readAll()
      let fresh: [EventEnvelope]
      do {
        fresh = try unboundCommands.importLibrary(library, log: current)
      } catch {
        errorMessage = "The export refers to a view it does not list."
        return
      }
      try log.append(fresh)
      show(current + fresh)
    } catch {
      errorMessage = Self.describe(error)
    }
  }
}

extension [ColumnEntry] {
  /// The tasks, then the sub-projects, each in the order they had; the tasks stay near the header.
  var tasksFirst: [ColumnEntry] {
    filter { if case .task = $0 { true } else { false } } + filter { if case .project = $0 { true } else { false } }
  }
}

// Damaged lines in the log.
extension LibraryViewModel {
  /// A sentence for the window when some lines of the log are unreadable, naming the first; `nil` otherwise.
  public var logProblemsMessage: String? {
    guard let first = logProblems.first else { return nil }
    let count = logProblems.count == 1 ? "1 line" : "\(logProblems.count) lines"
    return "\(count) of the event log could not be read and were left out, "
      + "starting with line \(first.line) of \(first.file)."
  }

  /// Moves this device's unreadable lines into a `.rejected` file beside the log, then reloads. Another
  /// device's damaged file stays as it is, to be repaired there.
  public func repairLog() {
    do {
      _ = try log.quarantineUnreadableLines()
    } catch {
      errorMessage = Self.describe(error)
      return
    }
    reload()
  }
}
