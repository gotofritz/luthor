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

  /// When the item is due by its own due date; `nil` if it has none.
  public func dueDate(of taskID: TaskID) -> DueDate? {
    dueDates[taskID]
  }

  /// When the item is due for ranking: its own due date, else the nearest ancestor's, hard or target as set
  /// there. A hard deadline on a project so ranks the tasks in it. The calendar shows a date only on the item
  /// that carries it.
  public func effectiveDueDate(of taskID: TaskID) -> DueDate? {
    var current: TaskID? = taskID
    var visited: Set<TaskID> = []
    while let id = current, visited.insert(id).inserted {
      if let due = dueDates[id] { return due }
      current = items[id]?.item.parentID
    }
    return nil
  }
}
