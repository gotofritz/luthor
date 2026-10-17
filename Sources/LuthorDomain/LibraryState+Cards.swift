extension LibraryState {
  /// Applies an edit made on a task's or project's card. Ignores a task that is not open and a project that
  /// is not active.
  mutating func applyCardEdit(_ payload: EventPayload) {
    switch payload {
    case .taskRenamed(let renamed):
      updateTask(renamed.taskID) { $0.title = renamed.title }
    case .taskNoted(let noted):
      updateTask(noted.taskID) { $0.notes = noted.notes }
    case .projectRenamed(let renamed):
      updateProject(renamed.projectID) { $0.title = renamed.title }
    case .projectNoted(let noted):
      updateProject(noted.projectID) { $0.notes = noted.notes }
    case .projectKindChanged(let changed):
      updateProject(changed.projectID) { $0.kind = changed.kind }
    default:
      break
    }
  }
}
