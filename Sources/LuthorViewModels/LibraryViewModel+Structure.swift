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

  /// Deletes a project for good, with its sub-projects and every task in them. If the columns showed it, or
  /// went through it, they show its parent, or with no parent the inbox.
  public func deleteProject(_ projectID: TaskID) {
    let parentID = knownProjects.first { $0.id == projectID }?.parentID
    let wasOnPath = path.contains(projectID)
    let events = perform { (log) throws(CommandError) in try commands.delete(projectID: projectID, log: log) }
    if wasOnPath, !events.isEmpty, let parentID { open(.project(parentID)) }
  }

  /// Turns a task into a project, which the columns then show, with a new task already being edited in it.
  public func addTasks(to taskID: TaskID) {
    let events = perform { (log) throws(CommandError) in try commands.promote(taskID: taskID, log: log) }
    for case .taskKindChanged(let changed) in events.map(\.payload) {
      beginNewItem(under: changed.taskID, kind: .task)
    }
  }

  /// Turns a project with nothing in it back into a task. If the columns showed it, they show its parent, or
  /// with no parent the inbox, and the task is selected where the list has it.
  public func turnIntoTask(_ projectID: TaskID) {
    let parentID = knownProjects.first { $0.id == projectID }?.parentID
    let wasShown = shownProjectID == projectID
    let events = perform { (log) throws(CommandError) in try commands.demote(projectID: projectID, log: log) }
    guard wasShown, !events.isEmpty else { return }
    open(parentID.map { .project($0) } ?? .inbox)
    if index(of: projectID) != nil { selection = projectID }
  }
}
