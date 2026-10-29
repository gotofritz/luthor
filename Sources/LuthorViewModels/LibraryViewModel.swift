import Foundation
import LuthorDomain
import LuthorStore
import Observation

/// The main window: one view at a time, with the sidebar of its inbox and projects, the open tasks of
/// the one shown, the capture fields and the keyboard selection. Everything listed comes from the
/// current view's state, so nothing of another view is ever shown.
///
/// An action runs on the state held and applies the events it writes to it, so it does not read the log. Events
/// another process appended are seen by `reload`, which the window calls when the log file changes, and new events
/// follow the highest Lamport counter seen.
@MainActor
@Observable
public final class LibraryViewModel {
  /// The one view the window shows; nothing from another view is ever listed.
  public internal(set) var currentView: ViewID
  /// The place the navigation rail has picked.
  public internal(set) var section = NavigationSection.inbox
  public internal(set) var sidebarSelection: SidebarItem = .inbox
  /// The priorities picked in the priorities section, `nil` being no priority; the list shows the tasks of
  /// all of them.
  public internal(set) var selectedPriorities: Set<Priority?> = []
  /// What Today's candidates are narrowed to; nothing is, until it is set. The tasks planned for the day stay.
  public var candidateFilter = TaskFilter() {
    didSet { present() }
  }
  /// Whether completed and dropped tasks and projects are listed too, dimmed, after the open ones.
  public var showCompleted = false {
    didSet { present() }
  }
  public var draft = ""
  public internal(set) var errorMessage: String?
  /// Lines of the log that could not be read, left out of what is shown; empty when the log is sound.
  public internal(set) var logProblems: [LogProblem] = []

  let log: any EventLog
  let injectedToday: (() -> CalendarDate)?
  let injectedMinutes: (() -> Int)?
  let systemClock: SystemClock
  let unboundCommands: Commands
  @ObservationIgnored var state = LibraryState.replay([])
  /// The highest Lamport counter of the log as last read or written here.
  @ObservationIgnored var lastLamport: UInt64 = 0
  /// The log's change token as of the state held, so an action reads the log only when it has changed since.
  @ObservationIgnored var loggedToken: String?
  /// The events `state` was replayed from, and how far the log was read, so what is appended later is folded in
  /// without reading the log again from its start.
  @ObservationIgnored var held = HeldLog()
  /// The commands run in this session that can be taken back, the latest last, and those undone that can be done
  /// again. Unlimited; a new command empties the second. Both are lost on quit, as nothing of them is written.
  var undoSteps: [UndoStep] = []
  var redoSteps: [UndoStep] = []
  /// Counts the changes of `state` and `held`, so a read made off the main actor knows if they moved on.
  @ObservationIgnored var generation = 0
  /// The state of the places that have a lot of it of their own, kept apart; `LibraryViewModel+Places.swift`
  /// forwards their properties, so a view reads them as ever.
  let dayModel: DayModel
  let tagsModel = TagsModel()
  let reviewModel = WeeklyReviewModel()
  let settingsModel = SettingsModel()
  let browserModel = BrowserModel()
  let listedModel = ListedModel()
  let selectionModel = SelectionModel()
  /// Counts the replays of the log. `state` is not observed, so a view reads it through `observing(_:)`, which reads
  /// this too, and the view is told when the log changes.
  var revision = 0
  @ObservationIgnored var layouts = DayLayoutCache()

  /// `today` and `now` tell the day and the minutes since it began; by default the system clock and "Day changes at" do.
  public init(
    log: any EventLog,
    commands: Commands,
    view: ViewID = .default,
    today: (() -> CalendarDate)? = nil,
    now: (() -> Int)? = nil,
    instant: @escaping () -> Date = { Date() },
    timeZone: TimeZone = .current
  ) {
    self.log = log
    unboundCommands = commands
    injectedToday = today
    injectedMinutes = now
    systemClock = SystemClock(instant: instant, timeZone: timeZone)
    currentView = view
    let day = today?() ?? systemClock.today(dayChangesAt: Settings.defaultDayChangesAt)
    dayModel = DayModel(view: view, day: day)
  }

  /// Shows another view, at its inbox, with no task selected.
  public func showView(_ viewID: ViewID) {
    candidateFilter = TaskFilter()
    currentView = viewID
    section = .inbox
    sidebarSelection = .inbox
    selection = nil
    editingCard = nil
    newItem = nil
    projectCardOpen = false
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
  public func moveProject(_ projectID: TaskID, toView viewID: ViewID) {
    perform { (log) throws(CommandError) in try commands.move(projectID: projectID, toView: viewID, log: log) }
  }

  /// What a project carries when dragged, so a drop can tell it from a task.
  public static func dragPayload(for projectID: TaskID) -> String {
    projectPayloadPrefix + projectID.rawValue
  }

  private static let projectPayloadPrefix = "project:"

  /// Handles payloads dropped on a project, or on the first column (`nil`): a project is nested there or
  /// made top-level, a task is filed into the project. Returns whether anything was dropped.
  @discardableResult
  public func drop(_ payloads: [String], on target: TaskID?) -> Bool {
    for payload in payloads {
      if payload.hasPrefix(Self.projectPayloadPrefix) {
        nest(TaskID(String(payload.dropFirst(Self.projectPayloadPrefix.count))), under: target)
      } else if let target {
        file(TaskID(payload), into: target)
      }
    }
    return !payloads.isEmpty
  }

  /// Nests a project in another, or with no parent makes it top-level. Nesting it under itself or one of
  /// its own sub-projects changes nothing.
  public func nest(_ projectID: TaskID, under parentID: TaskID?) {
    perform { (log) throws(CommandError) in try commands.move(projectID: projectID, under: parentID, log: log) }
  }

  /// Captures the draft as a new task. A blank draft captures nothing; a failed write keeps the draft.
  public func submit() {
    addTask(titled: draft, to: captureProjectID)
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
    newItem = nil
    projectCardOpen = false
    present()
  }

  /// Shows a section of the navigation rail, with no task selected. Leaving the projects closes the
  /// project shown.
  public func show(_ section: NavigationSection) {
    self.section = section
    viewBeingEdited = nil
    if section != .projects { sidebarSelection = .inbox }
    selection = nil
    editingCard = nil
    newItem = nil
    projectCardOpen = false
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

  /// Files a task into a project, or with `nil` takes it out of its project.
  public func file(_ taskID: TaskID, into projectID: TaskID?) {
    perform { (log) throws(CommandError) in try commands.move(taskID: taskID, to: projectID, log: log) }
  }

  /// Files the selected task and selects the one that takes its place in the list.
  public func fileSelected(into projectID: TaskID) {
    replaceSelected { file($0, into: projectID) }
  }

  /// Completes a project and its open tasks. If it repeats, the next one is made, due by its rule as of today.
  /// If the sidebar showed it, it shows the inbox again.
  public func completeProject(_ projectID: TaskID) {
    let day = clock()
    perform { (log) throws(CommandError) in try commands.completeProject(projectID, today: day, log: log) }
  }

  /// Opens a completed task again; a task that its project's completion took along stays completed.
  public func reopen(_ taskID: TaskID) {
    perform { (log) throws(CommandError) in try commands.reopen(taskID: taskID, log: log) }
  }

  /// Opens a completed project again, with what its completion took along.
  public func reopenProject(_ projectID: TaskID) {
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
  public func renameProject(_ projectID: TaskID, to title: String) {
    perform { (log) throws(CommandError) in try commands.renameProject(projectID, to: title, log: log) }
  }

  /// Makes a project sequential or parallel.
  public func setKind(of projectID: TaskID, to kind: ProjectKind) {
    perform { (log) throws(CommandError) in try commands.setKind(of: projectID, to: kind, log: log) }
  }

  /// Sets the notes of a project, or with blank text clears them.
  public func setNotes(ofProject projectID: TaskID, to notes: String) {
    perform { (log) throws(CommandError) in try commands.setNotes(ofProject: projectID, to: notes, log: log) }
  }

  /// Completes a task. If it repeats, the next one is made, due by its rule as of today.
  public func complete(_ taskID: TaskID) {
    let day = clock()
    pinPlace(of: taskID)
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
