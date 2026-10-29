/// One task on one day: the key of the minutes logged for it.
struct TaskDay: Hashable, Sendable {
  let taskID: TaskID
  let date: CalendarDate
}

/// The note a day was reviewed with; reviewed with no note is still reviewed.
struct DayNote: Equatable, Sendable {
  let text: String?
}

/// The estimate a task had when it was first planned for a day: what the review counts it at, however the
/// estimate changes later. `nil` minutes: it had none, so it counted at the default estimate.
struct PlannedEstimate: Equatable, Sendable {
  let minutes: Int?
}

/// What the daily review looks back on, kept apart from the rest of the state.
struct ReviewRecords: Equatable, Sendable {
  /// Minutes logged for a task on a day, as last set.
  private(set) var taskMinutes: [TaskDay: Int] = [:]
  /// The minutes logged for each task over all days: `taskMinutes` added up, kept so a task's history is not
  /// a scan of every logged day of every task.
  private(set) var taskTotals: [TaskID: Int] = [:]
  /// Minutes one view logged on a day for work outside the plan, as last set.
  var unplannedMinutes: [DayKey: Int] = [:]
  /// The days that were reviewed, with their notes.
  var reviews: [DayKey: DayNote] = [:]
  /// The day each completed task was planned for, so the review of that day can list it as done. A task that
  /// was planned for no day is not here.
  var plannedDays: [TaskID: CalendarDate] = [:]
  /// The estimate each task had when it was first planned for a day.
  var plannedEstimates: [TaskID: PlannedEstimate] = [:]

  /// Sets the minutes logged for a task on a day, or clears them with `nil`.
  mutating func setMinutes(_ minutes: Int?, for key: TaskDay) {
    let before = taskMinutes[key] ?? 0
    if let minutes {
      taskMinutes[key] = minutes
    } else {
      taskMinutes.removeValue(forKey: key)
    }
    let total = (taskTotals[key.taskID] ?? 0) - before + (minutes ?? 0)
    taskTotals[key.taskID] = total > 0 ? total : nil
  }

  /// Forgets all the time logged for these tasks.
  mutating func removeMinutes(ofTasks doomed: Set<TaskID>) {
    taskMinutes = taskMinutes.filter { !doomed.contains($0.key.taskID) }
    for id in doomed { taskTotals.removeValue(forKey: id) }
  }
}

/// A task as the review of a day lists it.
public struct ReviewEntry: Equatable, Sendable {
  public let task: TaskItem
  /// Minutes it was planned at: the estimate it had when first planned, or the default estimate if it had none.
  public let minutes: Int
  /// Minutes it is now: its estimate as it stands, which setting its times changes; the default while it has none.
  public let currentMinutes: Int
  /// Whether `minutes` is the default estimate, not one the task was given.
  public let isUnestimated: Bool
  /// The minutes logged for the task on the day reviewed; `nil` while none are.
  public let loggedMinutes: Int?
  /// What the task was estimated and how long it took over all days; `nil` until both are known.
  public let history: EstimateHistory?

  public init(
    task: TaskItem, minutes: Int, isUnestimated: Bool, loggedMinutes: Int?, history: EstimateHistory?,
    currentMinutes: Int? = nil
  ) {
    self.task = task
    self.minutes = minutes
    self.currentMinutes = currentMinutes ?? minutes
    self.isUnestimated = isUnestimated
    self.loggedMinutes = loggedMinutes
    self.history = history
  }
}

/// One view's day looked back on: what was done, what was not, and the time it took.
public struct DayReview: Equatable, Sendable {
  public let viewID: ViewID
  public let date: CalendarDate
  /// The tasks planned for the day that were completed, in the order they were completed.
  public let done: [ReviewEntry]
  /// The tasks planned for the day that are still open, in the order of the plan. Each wants a decision.
  public let notDone: [ReviewEntry]
  /// The minutes spent on work that was not in the plan.
  public let unplannedMinutes: Int
  /// The one-line note the day was reviewed with.
  public let note: String?
  public let isReviewed: Bool

  public init(
    viewID: ViewID,
    date: CalendarDate,
    done: [ReviewEntry],
    notDone: [ReviewEntry],
    unplannedMinutes: Int,
    note: String?,
    isReviewed: Bool
  ) {
    self.viewID = viewID
    self.date = date
    self.done = done
    self.notDone = notDone
    self.unplannedMinutes = unplannedMinutes
    self.note = note
    self.isReviewed = isReviewed
  }

  /// The minutes the planned tasks were counted at.
  public var estimatedMinutes: Int {
    (done + notDone).reduce(0) { $0 + $1.minutes }
  }

  /// The minutes logged for the planned tasks, not counting the unplanned ones.
  public var loggedMinutes: Int {
    (done + notDone).reduce(0) { $0 + ($1.loggedMinutes ?? 0) }
  }
}

/// What a task, or the tasks of a project, were estimated against the minutes they took. Shown to the user,
/// never applied: nothing here changes an estimate.
public struct EstimateHistory: Equatable, Sendable {
  /// The estimates of the tasks that have both an estimate and logged time.
  public let estimatedMinutes: Int
  /// The minutes logged for those tasks, over all days.
  public let loggedMinutes: Int
  /// How many tasks the two add up.
  public let taskCount: Int

  public init(estimatedMinutes: Int, loggedMinutes: Int, taskCount: Int) {
    self.estimatedMinutes = estimatedMinutes
    self.loggedMinutes = loggedMinutes
    self.taskCount = taskCount
  }

  /// How much longer than estimated; negative when it took less.
  public var differenceMinutes: Int {
    loggedMinutes - estimatedMinutes
  }
}

/// An open task planned for a day before today, still waiting for a decision.
public struct CarryOverEntry: Equatable, Sendable {
  public let entry: PlanEntry
  /// The day it was planned for.
  public let plannedFor: CalendarDate

  public init(entry: PlanEntry, plannedFor: CalendarDate) {
    self.entry = entry
    self.plannedFor = plannedFor
  }
}

/// A task planned for a day before today, with where it sits among the others of that day.
private struct LeftOver {
  let day: CalendarDate
  let key: PlanKey
  let task: TaskItem
}

// The daily review: how logging time and reviewing a day change the state, and the pure functions that turn
// it into a review, the leftovers of earlier days and the history of estimates. In its own file (SwiftLint
// file_length) rather than suppressed.
extension LibraryState {
  /// Applies the logging of time and the closing of a review; any other event changes nothing.
  mutating func applyReview(_ payload: EventPayload) {
    switch payload {
    case .taskTimeLogged(let logged):
      record(logged)
    case .unplannedTimeLogged(let logged):
      record(logged)
    case .dayReviewed(let reviewed):
      record(reviewed)
    default:
      break
    }
  }

  /// Logging nothing, or zero minutes, clears the day's time.
  mutating func record(_ logged: TaskTimeLogged) {
    let key = TaskDay(taskID: logged.taskID, date: logged.date)
    reviewRecords.setMinutes(logged.minutes.flatMap { $0 > 0 ? $0 : nil }, for: key)
  }

  /// Logging nothing, or zero minutes, clears the day's time.
  mutating func record(_ logged: UnplannedTimeLogged) {
    let key = DayKey(viewID: logged.viewID, date: logged.date)
    if let minutes = logged.minutes, minutes > 0 {
      reviewRecords.unplannedMinutes[key] = minutes
    } else {
      reviewRecords.unplannedMinutes.removeValue(forKey: key)
    }
  }

  mutating func record(_ reviewed: DayReviewed) {
    reviewRecords.reviews[DayKey(viewID: reviewed.viewID, date: reviewed.date)] = DayNote(text: reviewed.note)
  }

  /// The minutes logged for the task on that day; `nil` while none are.
  public func loggedMinutes(of taskID: TaskID, on date: CalendarDate) -> Int? {
    reviewRecords.taskMinutes[TaskDay(taskID: taskID, date: date)]
  }

  /// The minutes the view logged on that day for work outside the plan; `nil` while none are.
  public func unplannedMinutes(in viewID: ViewID, on date: CalendarDate) -> Int? {
    reviewRecords.unplannedMinutes[DayKey(viewID: viewID, date: date)]
  }

  /// Whether the view's day was reviewed.
  public func isReviewed(_ viewID: ViewID, on date: CalendarDate) -> Bool {
    reviewRecords.reviews[DayKey(viewID: viewID, date: date)] != nil
  }

  /// The note the view's day was reviewed with; `nil` while it has none.
  public func reviewNote(in viewID: ViewID, on date: CalendarDate) -> String? {
    reviewRecords.reviews[DayKey(viewID: viewID, date: date)]?.text
  }

  /// Whether the task exists: open or completed, but not dropped. A project is not a task.
  func hasTask(_ taskID: TaskID) -> Bool {
    existingTask(taskID) != nil
  }

  /// The estimate the task had when it was first planned for a day; its current one for a task never planned.
  func plannedEstimate(of task: TaskItem) -> Int? {
    guard let planned = reviewRecords.plannedEstimates[task.id] else { return task.estimate }
    return planned.minutes
  }

  /// Remembers the estimate a task has as the one it was planned with, unless it was planned before.
  mutating func notePlannedEstimate(of taskID: TaskID) {
    guard reviewRecords.plannedEstimates[taskID] == nil, let task = existingTask(taskID) else { return }
    reviewRecords.plannedEstimates[taskID] = PlannedEstimate(minutes: task.estimate)
  }

  /// The view's day looked back on, as of `today`.
  ///
  /// Done are the tasks planned for the day and completed since; not done are the tasks still planned for
  /// it. A task that was moved off the day, delegated, sent to someday or dropped no longer belongs to it:
  /// deciding on a task is what clears the day.
  public func dayReview(for viewID: ViewID, on date: CalendarDate, today: CalendarDate) -> DayReview {
    let defaultEstimate = settings(for: viewID).defaultEstimateMinutes
    // The estimate the task had when it was first planned, not the one it has now.
    func entry(_ task: TaskItem) -> ReviewEntry {
      let estimate = plannedEstimate(of: task)
      return ReviewEntry(
        task: task, minutes: estimate ?? defaultEstimate, isUnestimated: estimate == nil,
        loggedMinutes: loggedMinutes(of: task.id, on: date), history: estimateHistory(ofTask: task.id),
        currentMinutes: task.estimate ?? defaultEstimate)
    }
    let done = view(viewID).completedTasks.map(\.item).filter { reviewRecords.plannedDays[$0.id] == date }
      .map(entry)
    let notDone = plan(for: viewID, on: date, today: today).entries.map { entry($0.task) }
    return DayReview(
      viewID: viewID, date: date, done: done, notDone: notDone,
      unplannedMinutes: unplannedMinutes(in: viewID, on: date) ?? 0, note: reviewNote(in: viewID, on: date),
      isReviewed: isReviewed(viewID, on: date))
  }

  /// The view's open tasks planned for a day before `today`, oldest day first and in the suggested order
  /// within a day. Nothing carries them over: they wait here until the user decides on each.
  public func carryOver(in viewID: ViewID, today: CalendarDate) -> [CarryOverEntry] {
    let viewState = view(viewID)
    let defaultEstimate = settings(for: viewID).defaultEstimateMinutes
    let ranking = PlanRanking(viewState, dueDates: [:], on: today)
    let leftOver = viewState.openTasks.compactMap { task -> LeftOver? in
      guard let day = scheduledDates[task.id], day < today else { return nil }
      let manual = dayOrders[DayKey(viewID: viewID, date: day)]?.firstIndex(of: task.id)
      return LeftOver(day: day, key: ranking.key(task, manual: manual), task: task)
    }
    return leftOver.sorted { ($0.day, $0.key) < ($1.day, $1.key) }.map { found in
      let entry = PlanEntry(
        task: found.task, minutes: found.task.estimate ?? defaultEstimate, isUnestimated: found.task.estimate == nil,
        reason: "Left over from \(found.day.isoString)")
      return CarryOverEntry(entry: entry, plannedFor: found.day)
    }
  }

  /// What the task was estimated against the minutes logged for it over all days; `nil` unless it has an
  /// estimate and some logged time.
  public func estimateHistory(ofTask taskID: TaskID) -> EstimateHistory? {
    guard let task = existingTask(taskID), let estimate = plannedEstimate(of: task) else { return nil }
    guard let logged = reviewRecords.taskTotals[taskID] else { return nil }
    return EstimateHistory(estimatedMinutes: estimate, loggedMinutes: logged, taskCount: 1)
  }

  /// The histories of the tasks in the project and its sub-projects, open or completed, added up; `nil` while
  /// none of them has both an estimate and logged time.
  public func estimateHistory(ofProject projectID: TaskID) -> EstimateHistory? {
    var projectIDs = subtree(of: projectID)
    if projectIDs.isEmpty {
      let taken = completedProjects.filter { $0.item.id == projectID || $0.completedWith == projectID }
      projectIDs = Set(taken.map(\.item.id))
    }
    let tasks = openTasks + completedTasks.map(\.item)
    let histories = tasks.filter { $0.parentID.map(projectIDs.contains) ?? false }
      .compactMap { estimateHistory(ofTask: $0.id) }
    guard !histories.isEmpty else { return nil }
    return EstimateHistory(
      estimatedMinutes: histories.reduce(0) { $0 + $1.estimatedMinutes },
      loggedMinutes: histories.reduce(0) { $0 + $1.loggedMinutes }, taskCount: histories.count)
  }
}
