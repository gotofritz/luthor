// Repeating tasks: giving a task a rule, skipping one occurrence, and making the next task when one is done.
extension Commands {
  /// Makes the open task `taskID` repeat by `rule`, or with `nil` stops it repeating. A repeat needs a due date
  /// to count from, so a task with none is given `day` as a target date first. Setting the rule the task has
  /// writes nothing.
  public func setRepeat(
    taskID: TaskID,
    to rule: RepeatRule?,
    dueIfNone day: CalendarDate,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    guard state.isOpen(taskID) else { throw .noOpenTask(taskID.rawValue) }
    var events: [EventEnvelope] = []
    if rule != nil, state.dueDate(of: taskID) == nil {
      let due = TaskDueSet(taskID: taskID, date: day, isHard: false)
      events.append(envelope(EventID(ids.next()), .taskDueSet(due), log: log))
    }
    if state.repeatRule(of: taskID) != rule {
      let event = TaskRepeatSet(taskID: taskID, rule: rule)
      events.append(envelope(EventID(ids.next()), .taskRepeatSet(event), log: log + events))
    }
    return events
  }

  /// Passes over this occurrence of the repeating open task `taskID`: the next task is made as if this one had
  /// been done on `today`, and this one is dropped. Gives up nothing else, so the series goes on.
  public func skip(taskID: TaskID, today: CalendarDate, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let state = LibraryState.replay(log)
    guard state.openTasks.contains(where: { $0.id == taskID }) else { throw .noOpenTask(taskID.rawValue) }
    guard state.repeatRule(of: taskID) != nil else { throw .notRepeating(taskID) }
    var events = recurrence(of: taskID, on: today, state: state, log: log)
    events.append(envelope(EventID(ids.next()), .taskDropped(TaskDropped(taskID: taskID)), log: log + events))
    return events
  }

  /// The event that makes the next task of the repeating task `taskID`, done or skipped on `today`; none for a
  /// task that does not repeat, or whose next task exists already (the task was reopened and done again). With
  /// no `today` the task counts as done on its due date, and a task with no due date is counted from `today`.
  func recurrence(
    of taskID: TaskID,
    on today: CalendarDate?,
    state: LibraryState,
    log: [EventEnvelope]
  ) -> [EventEnvelope] {
    guard let rule = state.repeatRule(of: taskID) else { return [] }
    let next = TaskID.recurring(after: taskID)
    let due = state.dueDate(of: taskID)?.date
    guard !state.wasEverTask(next), let completedOn = today ?? due else { return [] }
    let nextDue = rule.nextDue(after: due ?? completedOn, completedOn: completedOn, today: completedOn)
    let recurred = TaskRecurred(previous: taskID, next: next, due: nextDue)
    return [envelope(EventID(ids.next()), .taskRecurred(recurred), log: log)]
  }
}
