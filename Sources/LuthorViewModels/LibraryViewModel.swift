import LuthorDomain
import LuthorStore
import Observation

/// The main window: one view at a time, with the sidebar of its inbox and projects, the open tasks of
/// the one shown, the capture fields and the keyboard selection. Everything listed comes from the
/// current view's state, so nothing of another view is ever shown.
///
/// Every action re-reads the log first, so events another process appended are never missed
/// and new events follow the highest Lamport counter on disk.
@MainActor
@Observable
public final class LibraryViewModel {
  /// Every view, the default one first.
  public internal(set) var views: [ViewItem] = []
  /// The one view the window shows; nothing from another view is ever listed.
  public internal(set) var currentView: ViewID
  /// The place the navigation rail has picked.
  public internal(set) var section = NavigationSection.inbox
  public internal(set) var sidebarSelection: SidebarItem = .inbox
  /// The priorities picked in the priorities section, `nil` being no priority; the list shows the tasks of
  /// all of them.
  public internal(set) var selectedPriorities: Set<Priority?> = []
  /// The tags of the view in creation order, how many open tasks each carries, and the one picked in the Tags
  /// place (`nil` until one is), whose open tasks that place lists.
  public internal(set) var tags: [TagItem] = []
  public internal(set) var tagTaskCounts: [TagID: Int] = [:]
  public internal(set) var selectedTagID: TagID?
  /// What Today's candidates are narrowed to; nothing is, until it is set. The tasks planned for the day stay.
  public var candidateFilter = TaskFilter() {
    didSet { present() }
  }
  /// Every active project of the view, nested or not, in creation order.
  public internal(set) var projects: [Project] = []
  /// The active projects of the view and, while completed items are listed, the completed ones: whatever a
  /// card can name as the project of a task.
  public internal(set) var knownProjects: [Project] = []
  /// The project the columns lead to, whose card is shown; a completed one too while completed items are
  /// listed. `nil` while the inbox, Today or the priorities are shown.
  public internal(set) var shownProject: Project?
  /// The project browser: the top-level projects, then one column for each project on the path.
  public internal(set) var columns: [ProjectColumn] = []
  /// The shown project and its ancestors, top-level first; empty while the inbox is shown.
  public internal(set) var path: [ProjectID] = []
  /// Open tasks of the inbox, of the project shown, or with a priority picked.
  public internal(set) var tasks: [TaskItem] = []
  /// The shown tasks that can be worked on now. Every inbox task is one.
  public internal(set) var nextActions: Set<TaskID> = []
  /// The settings with no per-view override applied.
  public internal(set) var globalSettings = LibraryState.replay([]).globalSettings
  /// The settings `currentView` plans with: its own overrides, then the global values.
  public internal(set) var viewSettings = LibraryState.replay([]).settings(for: .default)
  /// The default view chosen in settings.
  public internal(set) var defaultViewID = ViewID.default
  /// The day it is by the clock as of the last refresh, the day whose plan Today shows, that plan (planned
  /// tasks, candidates, capacity) for the current view, and the view's delegated tasks, longest wait first.
  public internal(set) var today: CalendarDate
  public internal(set) var planDate: CalendarDate
  public internal(set) var plan: DayPlan
  public internal(set) var waiting: [WaitingItem] = []
  /// The review of the day shown, and the open tasks planned for an earlier day than today, which wait at
  /// the top of Today until each is decided.
  public internal(set) var review: DayReview
  public internal(set) var carryOver: [CarryOverEntry] = []
  /// The calendar's days around today with their marks, the day picked on it (`nil` until one is) and that
  /// day's tasks: the ones planned for it, then those only due on it.
  public internal(set) var calendarDays: [CalendarDay] = []
  public internal(set) var calendarDate: CalendarDate?
  public internal(set) var calendarEntries: [CalendarEntry] = []
  /// The weekly review: the projects of the view whose review is due, the longest overdue first, the one
  /// picked (`nil` while none is due), and how often projects are reviewed unless they say otherwise.
  public internal(set) var projectReview: [ProjectReviewItem] = []
  public internal(set) var reviewProjectID: ProjectID?
  public internal(set) var reviewDefault = ReviewInterval.weekly
  /// Whether completed tasks and projects are listed too, dimmed, after the open ones.
  public var showCompleted = false {
    didSet { present() }
  }
  /// Of the completed items listed, those that can be reopened and those that came with their project.
  public internal(set) var completedTaskIDs: Set<TaskID> = []
  public internal(set) var completedProjectIDs: Set<ProjectID> = []
  public internal(set) var reopenableTaskIDs: Set<TaskID> = []
  public internal(set) var reopenableProjectIDs: Set<ProjectID> = []
  public var draft = ""
  /// Title of the next project to create.
  public var projectDraft = ""
  public var selection: TaskID? {
    didSet { if selection != oldValue { editingCard = nil } }
  }
  /// The card being edited, if any. Cards are read-only until Edit puts one here; OK and Cancel take it out.
  public internal(set) var editingCard: CardTarget?
  /// The task the Delegate dialog is asking about; the menus set it, the window shows the dialog.
  public var delegatingTaskID: TaskID?
  public internal(set) var errorMessage: String?

  let log: any EventLog
  let clock: () -> CalendarDate
  let commands: Commands
  @ObservationIgnored var state = LibraryState.replay([])

  /// `today` tells the day it is; the default is the system clock.
  public init(
    log: any EventLog,
    commands: Commands,
    view: ViewID = .default,
    today: @escaping () -> CalendarDate = { CalendarDate.systemToday() }
  ) {
    self.log = log
    self.commands = commands
    clock = today
    currentView = view
    let day = today()
    self.today = day
    planDate = day
    plan = LibraryState.replay([]).plan(for: view, on: day, today: day)
    review = LibraryState.replay([]).dayReview(for: view, on: day, today: day)
  }

  /// Shows another view, at its inbox, with no task selected.
  public func showView(_ viewID: ViewID) {
    candidateFilter = TaskFilter()
    currentView = viewID
    section = .inbox
    sidebarSelection = .inbox
    selection = nil
    editingCard = nil
    present()
  }

  /// Creates a view and shows it. A blank name, or one another view has, creates nothing.
  public func createView(named name: String) {
    let created = perform { (log) throws(CommandError) in try commands.createView(name: name, log: log) }
    for case .viewCreated(let view) in created.map(\.payload) {
      showView(view.viewID)
    }
  }

  /// Renames a view. A blank name, or one another view has, changes nothing.
  public func renameView(_ viewID: ViewID, to name: String) {
    perform { (log) throws(CommandError) in try commands.renameView(viewID, to: name, log: log) }
  }

  /// Takes a task across to another view, into its inbox.
  public func move(_ taskID: TaskID, toView viewID: ViewID) {
    perform { (log) throws(CommandError) in try commands.move(taskID: taskID, toView: viewID, log: log) }
  }

  /// Takes the selected task across to another view and selects the one that takes its place.
  public func moveSelected(toView viewID: ViewID) {
    replaceSelected { move($0, toView: viewID) }
  }

  /// Takes a project and its open tasks across to another view. If the sidebar showed it, it shows the
  /// inbox again.
  public func moveProject(_ projectID: ProjectID, toView viewID: ViewID) {
    perform { (log) throws(CommandError) in try commands.move(projectID: projectID, toView: viewID, log: log) }
  }

  /// What a project carries when dragged, so a drop can tell it from a task.
  public static func dragPayload(for projectID: ProjectID) -> String {
    projectPayloadPrefix + projectID.rawValue
  }

  private static let projectPayloadPrefix = "project:"

  /// Handles payloads dropped on a project, or on the first column (`nil`): a project is nested there or
  /// made top-level, a task is filed into the project. Returns whether anything was dropped.
  @discardableResult
  public func drop(_ payloads: [String], on target: ProjectID?) -> Bool {
    for payload in payloads {
      if payload.hasPrefix(Self.projectPayloadPrefix) {
        nest(ProjectID(String(payload.dropFirst(Self.projectPayloadPrefix.count))), under: target)
      } else if let target {
        file(TaskID(payload), into: target)
      }
    }
    return !payloads.isEmpty
  }

  /// Nests a project in another, or with no parent makes it top-level. Nesting it under itself or one of
  /// its own sub-projects changes nothing.
  public func nest(_ projectID: ProjectID, under parentID: ProjectID?) {
    perform { (log) throws(CommandError) in try commands.move(projectID: projectID, under: parentID, log: log) }
  }

  public func reload() {
    do {
      show(try log.readAll())
    } catch {
      errorMessage = Self.describe(error)
    }
  }

  /// Captures the draft as a new task. A blank draft captures nothing; a failed write keeps the draft.
  public func submit() {
    let title = draft
    let projectID = captureProjectID
    let viewID = currentView
    let day = clock()
    perform { (log) throws(CommandError) in
      if let projectID {
        try commands.capture(title: title, into: projectID, today: day, log: log)
      } else {
        try commands.capture(title: title, in: viewID, today: day, log: log)
      }
    }
    if errorMessage == nil { draft = "" }
  }

  /// Shows the inbox or a project, with no task selected.
  public func open(_ item: SidebarItem) {
    switch item {
    case .inbox: section = .inbox
    case .project: section = .projects
    }
    sidebarSelection = item
    selection = nil
    editingCard = nil
    present()
  }

  /// Shows a section of the navigation rail, with no task selected. Leaving the projects closes the
  /// project shown.
  public func show(_ section: NavigationSection) {
    self.section = section
    if section != .projects { sidebarSelection = .inbox }
    selection = nil
    editingCard = nil
    present()
  }

  /// The rows of the priorities section: the priorities, most urgent first, then no priority (`nil`).
  public static let priorityRows: [Priority?] = Priority.allCases.map { Optional($0) } + [nil]

  /// Picks exactly these priorities, as the list does for a click (one), a shift-click (a range) or a
  /// command-click (one added or dropped).
  public func selectPriorities(_ priorities: Set<Priority?>) {
    selectedPriorities = priorities
    present()
  }

  /// Picks a priority or, if it is picked, drops it. The others stay as they are.
  public func togglePriority(_ priority: Priority?) {
    if !selectedPriorities.insert(priority).inserted { selectedPriorities.remove(priority) }
    present()
  }

  /// Gives a task a priority, or with `nil` clears it.
  public func prioritize(_ taskID: TaskID, as priority: Priority?) {
    perform { (log) throws(CommandError) in try commands.prioritize(taskID: taskID, as: priority, log: log) }
  }

  /// Gives the selected task a priority, or with `nil` clears it.
  public func prioritizeSelected(as priority: Priority?) {
    guard let selected = selection else { return }
    prioritize(selected, as: priority)
  }

  /// Gives a task an estimate in minutes, or with `nil` clears it.
  public func estimate(_ taskID: TaskID, as minutes: Int?) {
    perform { (log) throws(CommandError) in try commands.estimate(taskID: taskID, as: minutes, log: log) }
  }

  /// Gives the selected task an estimate in minutes, or with `nil` clears it.
  public func estimateSelected(as minutes: Int?) {
    guard let selected = selection else { return }
    estimate(selected, as: minutes)
  }

  /// Creates a project titled by the project draft, inside the project shown, or top-level while the
  /// inbox is shown. A blank draft creates nothing; a failed write keeps the draft.
  public func createProject(kind: ProjectKind) {
    let title = projectDraft
    let viewID = currentView
    let parentID = shownProjectID
    let day = clock()
    perform { (log) throws(CommandError) in
      if let parentID {
        try commands.createProject(title: title, kind: kind, under: parentID, today: day, log: log)
      } else {
        try commands.createProject(title: title, kind: kind, in: viewID, today: day, log: log)
      }
    }
    if errorMessage == nil { projectDraft = "" }
  }

  /// Files a task into a project.
  public func file(_ taskID: TaskID, into projectID: ProjectID) {
    perform { (log) throws(CommandError) in try commands.move(taskID: taskID, to: projectID, log: log) }
  }

  /// Files the selected task and selects the one that takes its place in the list.
  public func fileSelected(into projectID: ProjectID) {
    replaceSelected { file($0, into: projectID) }
  }

  /// Completes a project and its open tasks. If the sidebar showed it, it shows the inbox again.
  public func completeProject(_ projectID: ProjectID) {
    perform { (log) throws(CommandError) in try commands.completeProject(projectID, log: log) }
  }

  /// Opens a completed task again; a task that its project's completion took along stays completed.
  public func reopen(_ taskID: TaskID) {
    perform { (log) throws(CommandError) in try commands.reopen(taskID: taskID, log: log) }
  }

  /// Opens a completed project again, with what its completion took along.
  public func reopenProject(_ projectID: ProjectID) {
    perform { (log) throws(CommandError) in try commands.reopenProject(projectID, log: log) }
  }

  /// Gives a task another title. A blank title changes nothing.
  public func rename(_ taskID: TaskID, to title: String) {
    perform { (log) throws(CommandError) in try commands.rename(taskID: taskID, to: title, log: log) }
  }

  /// Sets the notes of a task, or with blank text clears them.
  public func setNotes(_ taskID: TaskID, to notes: String) {
    perform { (log) throws(CommandError) in try commands.setNotes(taskID: taskID, to: notes, log: log) }
  }

  /// Gives a project another title. A blank title changes nothing.
  public func renameProject(_ projectID: ProjectID, to title: String) {
    perform { (log) throws(CommandError) in try commands.renameProject(projectID, to: title, log: log) }
  }

  /// Makes a project sequential or parallel.
  public func setKind(of projectID: ProjectID, to kind: ProjectKind) {
    perform { (log) throws(CommandError) in try commands.setKind(of: projectID, to: kind, log: log) }
  }

  /// Sets the notes of a project, or with blank text clears them.
  public func setNotes(ofProject projectID: ProjectID, to notes: String) {
    perform { (log) throws(CommandError) in try commands.setNotes(ofProject: projectID, to: notes, log: log) }
  }

  /// The selected task, whose card is shown.
  public var selectedTask: TaskItem? {
    selection.flatMap { selected in tasks.first { $0.id == selected } }
  }

  /// Completes a task. If it repeats, the next one is made, due by its rule as of today.
  public func complete(_ taskID: TaskID) {
    let day = clock()
    perform { (log) throws(CommandError) in try commands.complete(taskID: taskID, today: day, log: log) }
  }

  /// Moves the selection up (negative) or down (positive), stopping at the ends. With nothing selected,
  /// down selects the first task and up the last.
  public func moveSelection(by offset: Int) {
    guard let current = selection.flatMap(index(of:)) else {
      selection = (offset < 0 ? tasks.last : tasks.first)?.id
      return
    }
    selection = tasks[min(max(current + offset, 0), tasks.count - 1)].id
  }

  /// Completes the selected task and selects the one that takes its place in the list.
  public func completeSelected() {
    replaceSelected(complete)
  }
}
