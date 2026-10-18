import LuthorDomain

/// Duplicating a task, deleting a task or a project for good, and turning a task into a project. In their own
/// file (SwiftLint type_body_length) rather than suppressed.
extension LibraryViewModel {
  /// Makes a copy of a task, in the same place, and selects the copy if the list shown has it.
  public func duplicate(_ taskID: TaskID) {
    let day = clock()
    let events = perform { (log) throws(CommandError) in
      try commands.duplicate(taskID: taskID, today: day, log: log)
    }
    for case .taskDuplicated(let duplicated) in events.map(\.payload) where index(of: duplicated.copy) != nil {
      selection = duplicated.copy
    }
  }

  /// Makes a copy of the selected task.
  public func duplicateSelected() {
    guard let selected = selection else { return }
    duplicate(selected)
  }

  /// Deletes a task for good, open or completed. Unlike dropping it, nothing of it is left to find.
  public func deleteTask(_ taskID: TaskID) {
    perform { (log) throws(CommandError) in try commands.delete(taskID: taskID, log: log) }
  }

  /// Deletes a project for good, with its sub-projects and every task in them. If the columns showed it, they
  /// show the inbox again.
  public func deleteProject(_ projectID: TaskID) {
    perform { (log) throws(CommandError) in try commands.delete(projectID: projectID, log: log) }
  }

  /// Turns a task into a project, which the columns then show, ready for tasks to be captured into it.
  public func addTasks(to taskID: TaskID) {
    let events = perform { (log) throws(CommandError) in try commands.promote(taskID: taskID, log: log) }
    for case .taskKindChanged(let changed) in events.map(\.payload) {
      open(.project(changed.taskID))
    }
  }
}
