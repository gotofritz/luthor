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
