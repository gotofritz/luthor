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
    case .dayHoursSet(let hours):
      setHours(hours)
    case .taskStartSet(let start):
      setStart(start)
    case .dayBlockSet(let block):
      setBlock(block)
    case .dayBlockRemoved(let removed):
      dayBlocks.removeValue(forKey: removed.blockID)
    case .taskDueSet(let due):
      setDue(due)
    case .taskUnscheduled(let unscheduled):
      scheduledDates.removeValue(forKey: unscheduled.taskID)
      taskStarts.removeValue(forKey: unscheduled.taskID)
    case .taskReclaimed(let reclaimed):
      delegations.removeValue(forKey: reclaimed.taskID)
    default:
      break
    }
  }

  /// Ignores an item that is not open and a task that is delegated, which has to be reclaimed first.
  mutating func schedule(_ scheduled: TaskScheduled) {
    guard isOpen(scheduled.taskID), delegations[scheduled.taskID] == nil else { return }
    if scheduledDates[scheduled.taskID] != scheduled.date { taskStarts.removeValue(forKey: scheduled.taskID) }
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

  /// Ignores a block whose times do not make a stretch within one day.
  mutating func setBlock(_ block: DayBlockSet) {
    guard DayHours(start: block.start, end: block.end).isValid else { return }
    dayBlocks[block.blockID] = PlacedBlock(
      viewID: block.viewID, date: block.date,
      block: DayBlock(id: block.blockID, title: block.title, start: block.start, end: block.end))
  }

  /// The blocks of untracked time the view has on that day, earliest first.
  public func blocks(in viewID: ViewID, on date: CalendarDate) -> [DayBlock] {
    dayBlocks.values.filter { $0.viewID == viewID && $0.date == date }.map(\.block)
      .sorted { ($0.start, $0.id.rawValue) < ($1.start, $1.id.rawValue) }
  }

  /// Ignores a task that is not planned for the day the start was set for.
  mutating func setStart(_ start: TaskStartSet) {
    guard scheduledDates[start.taskID] == start.date else { return }
    if let minute = start.minute, (0..<24 * 60).contains(minute) {
      taskStarts[start.taskID] = TaskStart(date: start.date, minute: minute)
    } else {
      taskStarts.removeValue(forKey: start.taskID)
    }
  }

  /// The minute after midnight the task starts at on `date`, if it was given one for that day.
  public func startMinute(of taskID: TaskID, on date: CalendarDate) -> Int? {
    guard scheduledDates[taskID] == date, let start = taskStarts[taskID], start.date == date else { return nil }
    return start.minute
  }

  /// Hours that do not make a day, or only one end of them, clear the day's own hours.
  mutating func setHours(_ hours: DayHoursSet) {
    let key = DayKey(viewID: hours.viewID, date: hours.date)
    if let start = hours.start, let end = hours.end, DayHours(start: start, end: end).isValid {
      dayHours[key] = DayHours(start: start, end: end)
    } else {
      dayHours.removeValue(forKey: key)
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

  /// The hours set for the view on that day alone; `nil` while the weekday's hours apply.
  public func hoursOverride(in viewID: ViewID, on date: CalendarDate) -> DayHours? {
    dayHours[DayKey(viewID: viewID, date: date)]
  }

  /// The hours the view works on that day: its own for the day, else the weekday's from the settings.
  public func hours(in viewID: ViewID, on date: CalendarDate) -> DayHours {
    hoursOverride(in: viewID, on: date) ?? settings(for: viewID).dayHours[date.weekday] ?? .builtIn
  }

  /// The capacity set for the view on that day alone; `nil` while the weekday's capacity applies.
  public func capacityOverride(in viewID: ViewID, on date: CalendarDate) -> Int? {
    dayCapacities[DayKey(viewID: viewID, date: date)]
  }

  /// The view's plan for `date`, as of `today`.
  ///
  /// The plan lists the tasks planned for the day: the order the user chose first, then the rest in the
  /// suggested order. The suggestion is deterministic: by urgency, which is the priority's weight (A 0 days,
  /// B 10, C 20, none 30) plus the days left to the due date, hard or target (none counts as 30, one more than 90 days
  /// off as 90, an overdue one as less than zero), then by priority, then the order of the tasks in their
  /// projects, then the order they were captured. Candidates are the clarified open tasks that could be pulled in, and the
  /// unclarified ones whose hard deadline is due, in the same suggested order: no someday task, no task a
  /// sequential project is holding back, no delegated task until its follow-up date. A task planned for another day
  /// comes after all the others. A filter narrows the
  /// candidates only; the tasks planned for the day stay.
  public func plan(
    for viewID: ViewID, on date: CalendarDate, today: CalendarDate, matching filter: TaskFilter = TaskFilter()
  ) -> DayPlan {
    let viewState = view(viewID)
    let planning = settings(for: viewID)
    let dueDates = Dictionary(
      uniqueKeysWithValues: viewState.openTasks.compactMap { task -> (TaskID, DueDate)? in
        effectiveDueDate(of: task.id).map { (task.id, $0) }
      })
    let elsewhere = Set(scheduledDates.filter { $0.value != date }.keys)
    let ranking = PlanRanking(viewState, dueDates: dueDates, on: date, elsewhere: elsewhere)
    let key = DayKey(viewID: viewID, date: date)
    let manualPosition = Dictionary(
      (dayOrders[key] ?? []).enumerated().map { (position, id) in (id, position) },
      uniquingKeysWith: { first, _ in first })

    func entry(_ task: TaskItem) -> PlanEntry {
      PlanEntry(
        task: task, minutes: task.estimate ?? planning.defaultEstimateMinutes, isUnestimated: task.estimate == nil,
        reason: manualPosition[task.id] == nil ? ranking.reason(for: task) : "Your order",
        start: startMinute(of: task.id, on: date))
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
      let isClarified = task.isClarified || dueDates[task.id].map { $0.date <= date } ?? false
      return isClarified && task.priority != .someday && scheduledDates[task.id] != date
        && (task.parentID == nil || actionable.contains(task.id)) && !isWaiting && !isLeftOver
        && matches(task, filter, inProject: inProject)
    }.sorted(by: suggested).map(entry)

    let available = capacity(in: viewID, on: date, planning: planning)
    let percentage = min(max(planning.bufferPercentage, 0), 100)
    let capacity = DayCapacity(
      availableMinutes: available, bufferMinutes: available * percentage / 100,
      plannedMinutes: entries.reduce(0) { $0 + $1.minutes }, unestimatedCount: entries.filter(\.isUnestimated).count)
    return DayPlan(
      viewID: viewID, date: date, entries: entries, candidates: candidates, capacity: capacity,
      hours: hours(in: viewID, on: date), blocks: blocks(in: viewID, on: date))
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
  /// Days of urgency: the priority's weight plus the days to the hard deadline, the smaller the sooner.
  let urgency: Int
  let priority: Int
  let project: Int
  let capture: Int

  static func < (lhs: PlanKey, rhs: PlanKey) -> Bool {
    (lhs.manual, lhs.urgency, lhs.priority, lhs.project, lhs.capture)
      < (rhs.manual, rhs.urgency, rhs.priority, rhs.project, rhs.capture)
  }
}

/// What the suggested order of a view's tasks is made of.
struct PlanRanking {
  /// Where each task sits among the view's open tasks, in capture order.
  let captureIndex: [TaskID: Int]
  /// Where each task filed in a project sits in a walk through the view's projects, depth first.
  let projectIndex: [TaskID: Int]
  let projectTitles: [TaskID: String]
  /// The due date of each task that has one, hard deadline or target date.
  let dueDates: [TaskID: DueDate]
  /// Tasks planned for another day than the plan's: they rank after all the others.
  let elsewhere: Set<TaskID>
  /// The day the plan is for.
  let day: CalendarDate

  /// Days a task with no hard deadline counts as being from one.
  static let horizonDays = 30
  /// Days a hard deadline is capped at, so a task with a far-off one ranks below one with none.
  static let farDays = 90
  /// Added to the urgency of a task planned for another day, so it comes after every other task.
  static let elsewhereOffset = 10_000

  init(_ view: ViewState, dueDates: [TaskID: DueDate], on day: CalendarDate, elsewhere: Set<TaskID> = []) {
    self.dueDates = dueDates
    self.elsewhere = elsewhere
    self.day = day
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

  /// The place of a task in a plan: the user's own position first, then urgency, priority, project order,
  /// capture order.
  func key(_ task: TaskItem, manual: Int?) -> PlanKey {
    PlanKey(
      manual: manual ?? Int.max, urgency: urgency(of: task), priority: Self.rank(of: task.priority),
      project: projectIndex[task.id] ?? Int.max,
      capture: captureIndex[task.id] ?? Int.max)
  }

  /// The weight of the priority (A 0, B 10, C 20, none 30 days) plus the days left to the due date, at
  /// most the far limit, and none counting as the horizon. Overdue counts below zero, so it comes first.
  /// Someday tasks come last.
  private func urgency(of task: TaskItem) -> Int {
    let weight: Int
    switch task.priority {
    case .critical?: weight = 0
    case .important?: weight = 10
    case .optional?: weight = 20
    case nil: weight = Self.horizonDays
    case .someday?: return Int.max
    }
    let daysLeft = dueDates[task.id].map { $0.date.daysSinceEpoch - day.daysSinceEpoch } ?? Self.horizonDays
    if elsewhere.contains(task.id) { return Self.elsewhereOffset + weight + min(daysLeft, Self.farDays) }
    return weight + min(daysLeft, Self.farDays)
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
    if let due = dueDates[task.id] { reason += ", due \(due.date.isoString)" }
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
