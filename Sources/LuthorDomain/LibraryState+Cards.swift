extension LibraryState {
  /// Applies an edit made on an item's card. Ignores an item that is not open.
  mutating func applyCardEdit(_ payload: EventPayload) {
    switch payload {
    case .taskRenamed(let renamed):
      updateItem(renamed.taskID) { $0.title = renamed.title }
    case .taskNoted(let noted):
      updateItem(noted.taskID) { $0.notes = noted.notes }
    case .taskKindChanged(let changed):
      updateItem(changed.taskID) { $0.kind = changed.kind }
    default:
      break
    }
  }
}
