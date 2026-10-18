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
  /// The item the task is filed in; `nil` while it is top-level.
  public internal(set) var parentID: TaskID?
  /// How much the task matters; `nil` until it is given one.
  public internal(set) var priority: Priority?
  /// Minutes the task is expected to take; `nil` until it is given one.
  public internal(set) var estimate: Int?
  /// Plain-text notes; `nil` until it is given some.
  public internal(set) var notes: String?
  /// The day the task was captured; `nil` for one captured before cards showed it.
  public let createdOn: CalendarDate?
  /// How the item hands out its next actions once it is a project; `nil` for a task.
  public internal(set) var kind: ProjectKind?

  public init(
    id: TaskID,
    title: String,
    viewID: ViewID,
    parentID: TaskID? = nil,
    priority: Priority? = nil,
    estimate: Int? = nil,
    notes: String? = nil,
    createdOn: CalendarDate? = nil,
    kind: ProjectKind? = nil
  ) {
    self.id = id
    self.title = title
    self.viewID = viewID
    self.parentID = parentID
    self.priority = priority
    self.estimate = estimate
    self.notes = notes
    self.createdOn = createdOn
    self.kind = kind
  }

  /// Not yet clarified: no priority, no estimate and no parent.
  var isClarified: Bool {
    priority != nil || estimate != nil || parentID != nil
  }
}

/// Where an item stands. Completing or dropping a project takes the items open in it along; they come back
/// with it.
enum ItemStatus: Equatable, Sendable {
  case open
  /// Done; `with` is the project whose completion took it along, `nil` if it was completed itself.
  case completed(with: TaskID?)
  /// Given up; `with` is the project whose drop took it along, `nil` if it was dropped itself.
  case dropped(with: TaskID?)

  var isOpen: Bool {
    self == .open
  }

  /// Whether the item was completed or dropped itself, so it can be reopened on its own.
  var isReopenable: Bool {
    self == .completed(with: nil) || self == .dropped(with: nil)
  }

  /// Whether the completion or drop of the item `root` took this one along.
  func wasTaken(by root: TaskID) -> Bool {
    self == .completed(with: root) || self == .dropped(with: root)
  }
}

/// An item and where it stands.
struct StoredItem: Equatable, Sendable {
  var item: TaskItem
  var status: ItemStatus
}

/// The state of every view. Items are reachable only through `view(_:)`, which names the view: isolation
/// between views is a rule of the domain, not a filter in the UI.
public struct LibraryState: Equatable, Sendable {
  /// The default view, then the others in creation order.
  public private(set) var views = [ViewItem(id: .default, name: "Default")]
  /// Every item that exists, open, completed or dropped. Tasks and projects are the same thing: an item with
  /// `kind` set is a project.
  var items: [TaskID: StoredItem] = [:]
  /// The IDs of the items that exist, in capture order.
  var order: [TaskID] = []
  /// The items filed in each project, in the order they were filed: the open ones, and while the project is
  /// completed or dropped also those it took along.
  var filed: [TaskID: [TaskID]] = [:]
  /// The completed and dropped items, in the order they were; an item comes before those it took along.
  var finishedOrder: [TaskID] = []
  /// The position each item was captured at, so a reopened item goes back to its place among the others.
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
  /// How each task that repeats does so. Completing a task keeps its rule, as it does its due date.
  var repeatRules: [TaskID: RepeatRule] = [:]
  /// Every tag of every view, in creation order.
  var tagItems: [TagItem] = []
  /// The tags each open or completed task carries. A task with none is not here.
  var taskTags: [TaskID: Set<TagID>] = [:]
  /// The intervals, and the days, of the weekly project review.
  var projectReviews = ProjectReviewRecords()
  /// The manual order of each view's plan for a day, as last set.
  var dayOrders: [DayKey: [TaskID]] = [:]
  /// The capacity set for single days, in place of the weekday's.
  var dayCapacities: [DayKey: Int] = [:]
  /// What the daily review looks back on: logged time, reviewed days, and the day each completed task was
  /// planned for.
  var reviewRecords = ReviewRecords()

  /// The open tasks and projects, the completed and dropped ones, of one view; empty for a view that does not
  /// exist.
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
    case .taskRenamed, .taskNoted, .taskKindChanged:
      applyCardEdit(payload)
    case .taskMoved(let moved):
      move(moved)
    case .viewCreated(let created):
      create(created)
    case .viewRenamed(let renamed):
      rename(renamed)
    case .taskMovedToView(let moved):
      move(moved.taskID, toView: moved.viewID)
    case .taskPrioritized(let prioritized):
      prioritize(prioritized.taskID, as: prioritized.priority)
    case .taskEstimated(let estimated):
      estimate(estimated.taskID, as: estimated.minutes)
    case .settingChanged(let changed):
      change(changed)
    case .taskScheduled(let scheduled):
      schedule(scheduled)
    case .taskDelegated(let delegated):
      delegate(delegated)
    case .taskDropped(let dropped):
      drop(dropped.taskID)
    case .dayPlanOrdered, .dayCapacitySet, .taskDueSet, .taskUnscheduled, .taskReclaimed:
      applyPlanning(payload)
    case .tagCreated, .taskTagged, .taskUntagged:
      applyTagEvent(payload)
    case .taskTimeLogged, .unplannedTimeLogged, .dayReviewed:
      applyReview(payload)
    case .reviewDefaultSet, .reviewIntervalSet, .taskReviewed:
      applyProjectReview(payload)
    case .taskRepeatSet, .taskRecurred:
      applyRepeat(payload)
    case .taskDuplicated, .taskDeleted:
      applyStructure(payload)
    }
  }

  func hasView(_ viewID: ViewID) -> Bool {
    views.contains { $0.id == viewID }
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

  /// Ignores an item that is not open.
  private mutating func prioritize(_ taskID: TaskID, as priority: Priority?) {
    updateItem(taskID) { $0.priority = priority }
  }

  /// Ignores an item that is not open.
  private mutating func estimate(_ taskID: TaskID, as minutes: Int?) {
    updateItem(taskID) { $0.estimate = minutes }
  }
}
