extension Commands {
  /// Opens the completed task `taskID` again. A task that is open, or that its project's completion took
  /// along, is refused: reopen the project instead.
  public func reopen(taskID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    guard LibraryState.replay(log).completedTasks.contains(where: { $0.item.id == taskID && $0.isReopenable }) else {
      throw .noCompletedTask(taskID)
    }
    return [envelope(EventID(ids.next()), .taskReopened(TaskReopened(taskID: taskID)), log: log)]
  }

  /// Opens the completed project `projectID` again, with what its completion took along. A project that
  /// is active, or that another project's completion took along, is refused.
  public func reopenProject(_ projectID: ProjectID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    guard
      LibraryState.replay(log).completedProjects.contains(where: { $0.item.id == projectID && $0.isReopenable })
    else {
      throw .noCompletedProject(projectID)
    }
    return [envelope(EventID(ids.next()), .projectReopened(ProjectReopened(projectID: projectID)), log: log)]
  }
}
