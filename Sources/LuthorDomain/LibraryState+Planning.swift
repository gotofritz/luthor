/// Who a task was handed to, since when, and when it comes back to the candidates.
public struct Delegation: Equatable, Sendable {
  public let person: String
  /// The day it was handed over.
  public let since: CalendarDate
  /// The day it comes back; `nil` until it is reclaimed.
  public let followUpDate: CalendarDate?

  public init(to person: String, since: CalendarDate, followUpDate: CalendarDate?) {
    self.person = person
    self.since = since
    self.followUpDate = followUpDate
  }

  /// Whether the follow-up date has come on `today`. With no follow-up date it never does.
  public func isFollowUpDue(on today: CalendarDate) -> Bool {
    followUpDate.map { $0 <= today } ?? false
  }
}

/// One view's plan for one day: the key of its manual order and its capacity.
struct DayKey: Hashable, Sendable {
  let viewID: ViewID
  let date: CalendarDate
}

/// A task in a day's plan, or a candidate for it, with the minutes it counts for and why it sits there.
public struct PlanEntry: Equatable, Sendable {
  public let task: TaskItem
  /// Minutes it counts for: its estimate, or the default estimate while it has none.
  public let minutes: Int
  /// Whether `minutes` is the default estimate, not one the task was given.
  public let isUnestimated: Bool
  /// What put it here: the order the user chose, or the rule that suggested it.
  public let reason: String

  public init(task: TaskItem, minutes: Int, isUnestimated: Bool, reason: String) {
    self.task = task
    self.minutes = minutes
    self.isUnestimated = isUnestimated
    self.reason = reason
  }
}

/// How much of a day is spoken for. The buffer is protected capacity, never a task.
public struct DayCapacity: Equatable, Sendable {
  /// The day's capacity before the buffer.
  public let availableMinutes: Int
  /// Held back for interruptions and the unexpected.
  public let bufferMinutes: Int
  /// The minutes of the tasks in the plan, unestimated ones at the default estimate.
  public let plannedMinutes: Int
  /// How many of the planned tasks have no estimate of their own.
  public let unestimatedCount: Int

  public init(availableMinutes: Int, bufferMinutes: Int, plannedMinutes: Int, unestimatedCount: Int) {
    self.availableMinutes = availableMinutes
    self.bufferMinutes = bufferMinutes
    self.plannedMinutes = plannedMinutes
    self.unestimatedCount = unestimatedCount
  }

  /// What can be planned: the capacity less the buffer.
  public var usableMinutes: Int {
    availableMinutes - bufferMinutes
  }

  /// What is left to plan; negative when the plan is overloaded.
  public var remainingMinutes: Int {
    usableMinutes - plannedMinutes
  }

  /// Whether more is planned than can be done. A warning, never a refusal.
  public var isOverloaded: Bool {
    plannedMinutes > usableMinutes
  }
}

/// One view's day: the tasks planned for it in order, the tasks that could be pulled in, and the capacity.
public struct DayPlan: Equatable, Sendable {
  public let viewID: ViewID
  public let date: CalendarDate
  public let entries: [PlanEntry]
  public let candidates: [PlanEntry]
  public let capacity: DayCapacity

  public init(
    viewID: ViewID,
    date: CalendarDate,
    entries: [PlanEntry],
    candidates: [PlanEntry],
    capacity: DayCapacity
  ) {
    self.viewID = viewID
    self.date = date
    self.entries = entries
    self.candidates = candidates
    self.capacity = capacity
  }
}

/// A delegated task as the Waiting for list shows it.
public struct WaitingItem: Equatable, Sendable {
  public let task: TaskItem
  public let delegation: Delegation
  /// Whether the follow-up date has come, so the task is back among the candidates.
  public let isFollowUpDue: Bool

  public init(task: TaskItem, delegation: Delegation, isFollowUpDue: Bool) {
    self.task = task
    self.delegation = delegation
    self.isFollowUpDue = isFollowUpDue
  }
}

// Planning: how scheduling, delegating and dropping change the state, and the pure functions that turn it
// into a day's plan. In its own file (SwiftLint file_length) rather than suppressed.
extension LibraryState {
  /// Applies the events that set a day's order or capacity, a task's due date, and take a task off its day or
  /// back from the person it was delegated to; any other event changes nothing.
  mutating func applyPlanning(_ payload: EventPayload) {
    switch payload {
    case .dayPlanOrdered(let ordered):
      order(ordered)
    case .dayCapacitySet(let capacity):
      setCapacity(capacity)
    case .taskDueSet(let due):
      setDue(due)
    case .taskUnscheduled(let unscheduled):
      scheduledDates.removeValue(forKey: unscheduled.taskID)
    case .taskReclaimed(let reclaimed):
      delegations.removeValue(forKey: reclaimed.taskID)
    default:
      break
    }
  }

  /// Ignores an item that is not open and a task that is delegated, which has to be reclaimed first.
  mutating func schedule(_ scheduled: TaskScheduled) {
    guard isOpen(scheduled.taskID), delegations[scheduled.taskID] == nil else { return }
    scheduledDates[scheduled.taskID] = scheduled.date
  }

  /// Keeps a task named twice at its first place.
  mutating func order(_ ordered: DayPlanOrdered) {
    var seen = Set<TaskID>()
    dayOrders[DayKey(viewID: ordered.viewID, date: ordered.date)] = ordered.taskIDs.filter { seen.insert($0).inserted }
  }

  mutating func setCapacity(_ capacity: DayCapacitySet) {
    let key = DayKey(viewID: capacity.viewID, date: capacity.date)
    if let minutes = capacity.minutes {
      dayCapacities[key] = minutes
    } else {
      dayCapacities.removeValue(forKey: key)
    }
  }

  /// Takes the item off its day. Ignores an item that is not open.
  mutating func delegate(_ delegated: TaskDelegated) {
    guard isOpen(delegated.taskID) else { return }
    delegations[delegated.taskID] = Delegation(
      to: delegated.person, since: delegated.since, followUpDate: delegated.followUpDate)
    scheduledDates.removeValue(forKey: delegated.taskID)
  }

  /// Forgets the day and the delegation of a task that is completed, dropped or taken to another view.
  mutating func forgetPlanning(of taskID: TaskID) {
    scheduledDates.removeValue(forKey: taskID)
    delegations.removeValue(forKey: taskID)
  }

  /// The day the task is planned for; `nil` if it is planned for none.
  public func scheduledDate(of taskID: TaskID) -> CalendarDate? {
    scheduledDates[taskID]
  }

  /// Who has the task; `nil` unless it is delegated.
  public func delegation(of taskID: TaskID) -> Delegation? {
    delegations[taskID]
  }

  /// The order the user chose for the view's plan on a day; `nil` while none was chosen.
  public func manualOrder(in viewID: ViewID, on date: CalendarDate) -> [TaskID]? {
    dayOrders[DayKey(viewID: viewID, date: date)]
  }

  /// The capacity set for the view on that day alone; `nil` while the weekday's capacity applies.
  public func capacityOverride(in viewID: ViewID, on date: CalendarDate) -> Int? {
    dayCapacities[DayKey(viewID: viewID, date: date)]
  }

  /// The view's plan for `date`, as of `today`.
  ///
  /// The plan lists the tasks planned for the day: the order the user chose first, then the rest in the
  /// suggested order. The suggestion is deterministic: A before B before C, then hard deadlines that are due
  /// on the day (the earliest first), then the order of the tasks in their projects, then the order they were
  /// captured. Candidates are the clarified open tasks that could be pulled in, and the unclarified ones whose
  /// hard deadline is due, in the same suggested order: no someday task, no task a sequential project is
  /// holding back, no delegated task until its follow-up date. A filter narrows the candidates only; the tasks
  /// planned for the day stay.
  public func plan(
    for viewID: ViewID, on date: CalendarDate, today: CalendarDate, matching filter: TaskFilter = TaskFilter()
  ) -> DayPlan {
    let viewState = view(viewID)
    let planning = settings(for: viewID)
    let deadlines = Dictionary(
      uniqueKeysWithValues: viewState.openTasks.compactMap { task -> (TaskID, CalendarDate)? in
        guard let due = effectiveDueDate(of: task.id), due.isHard, due.date <= date else { return nil }
        return (task.id, due.date)
      })
    let ranking = PlanRanking(viewState, deadlines: deadlines)
    let key = DayKey(viewID: viewID, date: date)
    let manualPosition = Dictionary(
      (dayOrders[key] ?? []).enumerated().map { (position, id) in (id, position) },
      uniquingKeysWith: { first, _ in first })

    func entry(_ task: TaskItem) -> PlanEntry {
      PlanEntry(
        task: task, minutes: task.estimate ?? planning.defaultEstimateMinutes, isUnestimated: task.estimate == nil,
        reason: manualPosition[task.id] == nil ? ranking.reason(for: task) : "Your order")
    }
    func suggested(_ lhs: TaskItem, before rhs: TaskItem) -> Bool {
      ranking.key(lhs, manual: manualPosition[lhs.id]) < ranking.key(rhs, manual: manualPosition[rhs.id])
    }

    let entries = viewState.openTasks.filter { scheduledDates[$0.id] == date }.sorted(by: suggested).map(entry)
    let actionable = Set(viewState.nextActions.map(\.id))
    let inProject = filter.projectID.map(subtree(of:))
    let candidates = viewState.openTasks.filter { task in
      let isWaiting = delegations[task.id].map { !$0.isFollowUpDue(on: today) } ?? false
      let isLeftOver = scheduledDates[task.id].map { $0 < today } ?? false
      let isClarified = task.isClarified || deadlines[task.id] != nil
      return isClarified && task.priority != .someday && scheduledDates[task.id] != date
        && (task.parentID == nil || actionable.contains(task.id)) && !isWaiting && !isLeftOver
        && matches(task, filter, inProject: inProject)
    }.sorted(by: suggested).map(entry)

    let weekday = date.weekday
    let available = max(0, dayCapacities[key] ?? planning.capacity[weekday] ?? weekday.builtInCapacityMinutes)
    let percentage = min(max(planning.bufferPercentage, 0), 100)
    let capacity = DayCapacity(
      availableMinutes: available, bufferMinutes: available * percentage / 100,
      plannedMinutes: entries.reduce(0) { $0 + $1.minutes }, unestimatedCount: entries.filter(\.isUnestimated).count)
    return DayPlan(viewID: viewID, date: date, entries: entries, candidates: candidates, capacity: capacity)
  }

  /// The view's delegated tasks, the longest wait first.
  public func waitingFor(in viewID: ViewID, today: CalendarDate) -> [WaitingItem] {
    let waiting = view(viewID).openTasks.enumerated().compactMap { (position, task) -> (Int, WaitingItem)? in
      guard let delegation = delegations[task.id] else { return nil }
      let item = WaitingItem(task: task, delegation: delegation, isFollowUpDue: delegation.isFollowUpDue(on: today))
      return (position, item)
    }
    return waiting.sorted { ($0.1.delegation.since, $0.0) < ($1.1.delegation.since, $1.0) }.map { $0.1 }
  }
}

/// Where a task sits in a plan; the smaller key goes first.
struct PlanKey: Comparable {
  let manual: Int
  let priority: Int
  /// The day of a hard deadline that is due, else `Int.max`.
  let deadline: Int
  let project: Int
  let capture: Int

  static func < (lhs: PlanKey, rhs: PlanKey) -> Bool {
    (lhs.manual, lhs.priority, lhs.deadline, lhs.project, lhs.capture)
      < (rhs.manual, rhs.priority, rhs.deadline, rhs.project, rhs.capture)
  }
}

/// What the suggested order of a view's tasks is made of.
struct PlanRanking {
  /// Where each task sits among the view's open tasks, in capture order.
  let captureIndex: [TaskID: Int]
  /// Where each task filed in a project sits in a walk through the view's projects, depth first.
  let projectIndex: [TaskID: Int]
  let projectTitles: [TaskID: String]
  /// The day of the hard deadline of each task whose deadline is due.
  let deadlines: [TaskID: CalendarDate]

  init(_ view: ViewState, deadlines: [TaskID: CalendarDate]) {
    self.deadlines = deadlines
    let captured = view.openTasks.enumerated().map { (position, task) in (task.id, position) }
    captureIndex = Dictionary(captured, uniquingKeysWith: { first, _ in first })
    projectTitles = Dictionary(view.projects.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
    var index: [TaskID: Int] = [:]
    func visit(_ project: Project) {
      for child in project.children {
        switch child {
        case .task(let task):
          let position = index.count
          index[task.id] = position
        case .project(let projectID):
          if let nested = view.projects.first(where: { $0.id == projectID }) { visit(nested) }
        }
      }
    }
    view.topLevelProjects.forEach(visit)
    projectIndex = index
  }

  /// The place of a task in a plan: the user's own position first, then priority, deadline, project order,
  /// capture order.
  func key(_ task: TaskItem, manual: Int?) -> PlanKey {
    PlanKey(
      manual: manual ?? Int.max, priority: Self.rank(of: task.priority),
      deadline: deadlines[task.id]?.daysSinceEpoch ?? Int.max, project: projectIndex[task.id] ?? Int.max,
      capture: captureIndex[task.id] ?? Int.max)
  }

  func reason(for task: TaskItem) -> String {
    let priority: String =
      switch task.priority {
      case .critical?: "A priority"
      case .important?: "B priority"
      case .optional?: "C priority"
      case .someday?: "Someday"
      case nil: "No priority"
      }
    var reason = priority
    if let parentID = task.parentID, let title = projectTitles[parentID] { reason += ", in project \(title)" }
    if let deadline = deadlines[task.id] { reason += ", deadline \(deadline.isoString)" }
    return reason
  }

  private static func rank(of priority: Priority?) -> Int {
    switch priority {
    case .critical?: 0
    case .important?: 1
    case .optional?: 2
    case nil: 3
    case .someday?: 4
    }
  }
}
