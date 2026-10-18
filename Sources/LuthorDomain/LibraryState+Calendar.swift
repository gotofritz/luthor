/// One day of the calendar, with how many tasks are planned for it and how many are due on it.
public struct CalendarDay: Equatable, Identifiable, Sendable {
  public let date: CalendarDate
  /// Open tasks planned for the day.
  public let plannedCount: Int
  /// Open tasks due on the day, hard deadline or target date.
  public let dueCount: Int

  public var id: CalendarDate {
    date
  }

  /// Whether anything is planned for the day or due on it, so the calendar marks it.
  public var hasTasks: Bool {
    plannedCount > 0 || dueCount > 0
  }

  public init(date: CalendarDate, plannedCount: Int, dueCount: Int) {
    self.date = date
    self.plannedCount = plannedCount
    self.dueCount = dueCount
  }
}

/// A task of a calendar day, and why it is on it.
public struct CalendarEntry: Equatable, Sendable {
  public let task: TaskItem
  /// Whether the task is planned for the day.
  public let isPlanned: Bool
  /// The due date of the task if it is due on the day; `nil` if it is due on another or has none.
  public let due: DueDate?

  public init(task: TaskItem, isPlanned: Bool, due: DueDate?) {
    self.task = task
    self.isPlanned = isPlanned
    self.due = due
  }
}

// The calendar: which days have tasks, and which tasks a day has. Both are pure functions of the state, so
// the calendar stores nothing of its own.
extension LibraryState {
  /// `days` days in a row from `start`, each with the view's open tasks planned for it and the open items, tasks
  /// and projects, that carry a due date on it.
  public func calendar(for viewID: ViewID, from start: CalendarDate, days: Int) -> [CalendarDay] {
    var planned: [CalendarDate: Int] = [:]
    var due: [CalendarDate: Int] = [:]
    for task in view(viewID).openTasks {
      if let day = scheduledDates[task.id] { planned[day, default: 0] += 1 }
    }
    for item in openItems(in: viewID) {
      if let day = dueDates[item.id]?.date { due[day, default: 0] += 1 }
    }
    return (0..<max(days, 0)).map { offset in
      let day = start.adding(days: offset)
      return CalendarDay(date: day, plannedCount: planned[day] ?? 0, dueCount: due[day] ?? 0)
    }
  }

  /// The view's open tasks planned for `date`, in the order of its plan, then those due on it that are not
  /// planned for it, in capture order.
  public func calendarEntries(for viewID: ViewID, on date: CalendarDate, today: CalendarDate) -> [CalendarEntry] {
    let planned = plan(for: viewID, on: date, today: today).entries.map(\.task)
    let plannedIDs = Set(planned.map(\.id))
    func entry(_ task: TaskItem, isPlanned: Bool) -> CalendarEntry {
      CalendarEntry(task: task, isPlanned: isPlanned, due: dueDates[task.id].flatMap { $0.date == date ? $0 : nil })
    }
    let dueOnly = openItems(in: viewID).filter { !plannedIDs.contains($0.id) && dueDates[$0.id]?.date == date }
    return planned.map { entry($0, isPlanned: true) } + dueOnly.map { entry($0, isPlanned: false) }
  }
}
