extension Commands {
  /// Opens the completed or dropped task `taskID` again. A task that is open, or that its project's completion
  /// or drop took along, is refused: reopen the project instead.
  public func reopen(taskID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    let state = libraryState(from: log)
    guard
      state.completedTasks.contains(where: { $0.item.id == taskID && $0.isReopenable })
        || state.completedProjects.contains(where: { $0.item.id == taskID && $0.isReopenable })
    else {
      throw .noCompletedTask(taskID)
    }
    return [envelope(EventID(ids.next()), .taskReopened(TaskReopened(taskID: taskID)), log: log)]
  }

  /// Dates every completion that has no day, once, so the Completed Tasks window can count from it: the task's
  /// due date, else the day it was planned for, else three days before `today`. A completion that has a day,
  /// and a dropped item, is left alone, so a second run finds nothing to do.
  public func dateOldCompletions(today: CalendarDate, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    let state = libraryState(from: log)
    var written: [EventEnvelope] = []
    let finished =
      state.completedTasks.map { (id: $0.item.id, isDropped: $0.isDropped, completedOn: $0.completedOn) }
      + state.completedProjects.map { (id: $0.item.id, isDropped: $0.isDropped, completedOn: $0.completedOn) }
    for (id, isDropped, completedOn) in finished {
      guard !isDropped, completedOn == nil else { continue }
      let day = state.dueDate(of: id)?.date ?? state.plannedDay(of: id) ?? today.adding(days: -3)
      let dated = CompletionDated(taskID: id, completedOn: day)
      written.append(envelope(EventID(ids.next()), .completionDated(dated), log: log + written))
    }
    return written
  }

  /// Opens the completed or dropped project `projectID` again, with what its completion or drop took along. A
  /// project that is open, or that another project's completion or drop took along, is refused.
  public func reopenProject(_ projectID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    guard
      libraryState(from: log).completedProjects.contains(where: { $0.item.id == projectID && $0.isReopenable })
    else {
      throw .noCompletedProject(projectID)
    }
    return [envelope(EventID(ids.next()), .taskReopened(TaskReopened(taskID: projectID)), log: log)]
  }
}
