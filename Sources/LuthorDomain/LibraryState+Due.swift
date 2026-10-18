/// When a task is due. A hard deadline surfaces in Today's candidates once it is due, ahead of tasks of its
/// priority; a target date is only shown, on the card and the calendar.
public struct DueDate: Equatable, Sendable {
  public let date: CalendarDate
  /// Whether `date` is a hard deadline, not a target date.
  public let isHard: Bool

  public init(date: CalendarDate, isHard: Bool) {
    self.date = date
    self.isHard = isHard
  }
}

extension LibraryState {
  /// Ignores an item that is not open.
  mutating func setDue(_ due: TaskDueSet) {
    guard isOpen(due.taskID) else { return }
    dueDates[due.taskID] = due.date.map { DueDate(date: $0, isHard: due.isHard) }
  }

  /// When the task is due; `nil` if it has no due date.
  public func dueDate(of taskID: TaskID) -> DueDate? {
    dueDates[taskID]
  }
}
