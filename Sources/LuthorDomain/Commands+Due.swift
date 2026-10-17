extension Commands {
  /// Gives the open task `taskID` a due date, a hard deadline or a target date, or with `nil` clears it. The
  /// due date it has writes nothing.
  public func setDue(
    taskID: TaskID,
    to date: CalendarDate?,
    isHard: Bool,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    guard state.openTasks.contains(where: { $0.id == taskID }) else { throw .noOpenTask(taskID.rawValue) }
    let due = date.map { DueDate(date: $0, isHard: isHard) }
    guard state.dueDate(of: taskID) != due else { return [] }
    let event = TaskDueSet(taskID: taskID, date: date, isHard: due?.isHard ?? false)
    return [envelope(EventID(ids.next()), .taskDueSet(event), log: log)]
  }
}
