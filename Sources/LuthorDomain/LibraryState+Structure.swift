// Duplicating a task and deleting an item for good. In their own file (SwiftLint file_length) rather than
// suppressed.
extension LibraryState {
  /// Applies the events that duplicate or delete; any other event changes nothing.
  mutating func applyStructure(_ payload: EventPayload) {
    switch payload {
    case .taskDuplicated(let duplicated):
      duplicate(duplicated)
    case .taskDeleted(let deleted):
      delete(deleted.taskID)
    default:
      break
    }
  }

  /// Makes the open task `copyID` out of the task `sourceID`, which is open or completed: in its parent if that
  /// is open and in its view, else loose, with its title, notes, priority, estimate, tags and rule. Returns
  /// whether it did; it does not for a `copyID` that exists already, so two devices making the same copy make
  /// one, nor for a `sourceID` that does not exist.
  mutating func copyTask(_ sourceID: TaskID, as copyID: TaskID, createdOn: CalendarDate?) -> Bool {
    guard captureOrder[copyID] == nil, let source = existingTask(sourceID) else { return false }
    captureOrder[copyID] = captureOrder.count
    order.append(copyID)
    items[copyID] = StoredItem(
      item: TaskItem(
        id: copyID, title: source.title, viewID: source.viewID, priority: source.priority,
        estimate: source.estimate, notes: source.notes, createdOn: createdOn, kind: source.kind),
      status: .open)
    if let parentID = source.parentID, isOpen(parentID, in: source.viewID) { file(copyID, under: parentID) }
    taskTags[copyID] = taskTags[sourceID]
    repeatRules[copyID] = repeatRules[sourceID]
    return true
  }

  /// Whether the project exists: open, completed or dropped, but not deleted.
  func hasProject(_ projectID: TaskID) -> Bool {
    items[projectID]?.item.kind != nil
  }

  /// Copies the task, and its due date with it.
  private mutating func duplicate(_ duplicated: TaskDuplicated) {
    guard copyTask(duplicated.source, as: duplicated.copy, createdOn: duplicated.createdOn) else { return }
    dueDates[duplicated.copy] = dueDates[duplicated.source]
  }

  /// Takes an item, open, completed or dropped, out of every list with every item filed in it at any depth, and
  /// forgets what was set on them. Their place in the capture order stays, so capturing one again or reopening
  /// it brings nothing back. Ignores an item that does not exist.
  private mutating func delete(_ taskID: TaskID) {
    let doomed = family(of: taskID)
    guard !doomed.isEmpty else { return }
    unfile(taskID)
    order.removeAll { doomed.contains($0) }
    finishedOrder.removeAll { doomed.contains($0) }
    for id in doomed {
      items.removeValue(forKey: id)
      filed.removeValue(forKey: id)
      forgetPlanning(of: id)
      dueDates.removeValue(forKey: id)
      repeatRules.removeValue(forKey: id)
      taskTags.removeValue(forKey: id)
      reviewRecords.plannedDays.removeValue(forKey: id)
      projectReviews.intervals.removeValue(forKey: id)
      projectReviews.reviewedOn.removeValue(forKey: id)
    }
    reviewRecords.taskMinutes = reviewRecords.taskMinutes.filter { !doomed.contains($0.key.taskID) }
  }

  /// The item and every item that has it as an ancestor, in any state; empty for an item that does not exist.
  private func family(of taskID: TaskID) -> Set<TaskID> {
    guard items[taskID] != nil else { return [] }
    var found: Set<TaskID> = [taskID]
    var grew = true
    while grew {
      let size = found.count
      for stored in items.values {
        if let parentID = stored.item.parentID, found.contains(parentID) { found.insert(stored.item.id) }
      }
      grew = found.count > size
    }
    return found
  }
}
