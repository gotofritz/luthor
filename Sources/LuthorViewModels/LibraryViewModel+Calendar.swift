import LuthorDomain

// Due dates and the calendar: the days around today with their marks, the day picked on it, and giving a task
// a due date. In its own file (SwiftLint file_length) rather than suppressed.
extension LibraryViewModel {
  /// How many days before today, and after it, the calendar lists.
  static let calendarDaysBefore = 60
  static let calendarDaysAfter = 365

  /// Picks a day on the calendar, which lists its tasks, with no task selected.
  public func showCalendarDay(_ date: CalendarDate) {
    calendarDate = date
    selection = nil
    editingCard = nil
    newItem = nil
    present()
  }

  /// Gives a task a due date, a hard deadline or a target date, or with `nil` clears it.
  public func setDue(_ taskID: TaskID, to date: CalendarDate?, isHard: Bool) {
    perform { (log) throws(CommandError) in
      try commands.setDue(taskID: taskID, to: date, isHard: isHard, log: log)
    }
  }

  /// When a task is due; `nil` if it has no due date.
  public func dueDate(of taskID: TaskID) -> DueDate? {
    state.dueDate(of: taskID)
  }

  /// Fills the calendar's days and the tasks of the day picked.
  func presentCalendar() {
    let first = today.adding(days: -Self.calendarDaysBefore)
    let count = Self.calendarDaysBefore + Self.calendarDaysAfter + 1
    calendarDays = state.calendar(for: currentView, from: first, days: count)
    calendarEntries = calendarDate.map { state.calendarEntries(for: currentView, on: $0, today: today) } ?? []
  }
}
