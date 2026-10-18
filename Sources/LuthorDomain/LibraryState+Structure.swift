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

  /// Makes the open item `copyID` out of the item `sourceID`, which is open or completed: in its parent if that
  /// is open and in its view, else loose, with its title, notes, priority, estimate, tags and rule, and a copy
  /// of everything filed in it that was not given up (see `copySubtree`). Returns whether it did; it does not
  /// for a `copyID` that exists already, so two devices making the same copy make one, nor for a `sourceID`
  /// that does not exist or was given up.
  mutating func copyTask(
    _ sourceID: TaskID,
    as copyID: TaskID,
    createdOn: CalendarDate?,
    keepingDueDates: Bool
  ) -> Bool {
    guard captureOrder[copyID] == nil, let source = existingItem(sourceID) else { return false }
    makeCopy(of: source, as: copyID, createdOn: createdOn)
    if let parentID = source.parentID, isOpen(parentID, in: source.viewID) { file(copyID, under: parentID) }
    copySubtree(of: sourceID, to: copyID, createdOn: createdOn, keepingDueDates: keepingDueDates)
    return true
  }

  private mutating func makeCopy(of source: TaskItem, as copyID: TaskID, createdOn: CalendarDate?) {
    captureOrder[copyID] = captureOrder.count
    order.append(copyID)
    items[copyID] = StoredItem(
      item: TaskItem(
        id: copyID, title: source.title, viewID: source.viewID, priority: source.priority,
        estimate: source.estimate, notes: source.notes, createdOn: createdOn, kind: source.kind),
      status: .open)
    taskTags[copyID] = taskTags[source.id]
    repeatRules[copyID] = repeatRules[source.id]
  }

  /// Makes an open copy of every item that has `sourceID` as its parent and was not given up, completed or not,
  /// filed in `copyID`, and of what is filed in them, with IDs worked out from `copyID`. A copy of a repeat
  /// starts afresh, so its tasks keep their due dates only when `keepingDueDates`.
  private mutating func copySubtree(
    of sourceID: TaskID, to copyID: TaskID, createdOn: CalendarDate?, keepingDueDates: Bool
  ) {
    let children = order.filter { id in
      guard let stored = items[id], stored.item.parentID == sourceID else { return false }
      if case .dropped = stored.status { return false }
      return true
    }
    for childID in children {
      guard let child = items[childID]?.item else { continue }
      let childCopy = TaskID.copied(childID, under: copyID)
      guard captureOrder[childCopy] == nil else { continue }
      makeCopy(of: child, as: childCopy, createdOn: createdOn)
      file(childCopy, under: copyID)
      if keepingDueDates { dueDates[childCopy] = dueDates[childID] }
      copySubtree(of: childID, to: childCopy, createdOn: createdOn, keepingDueDates: keepingDueDates)
    }
  }

  /// Whether the project exists: open, completed or dropped, but not deleted.
  func hasProject(_ projectID: TaskID) -> Bool {
    items[projectID]?.item.kind != nil
  }

  /// Copies the task, and its due date with it.
  private mutating func duplicate(_ duplicated: TaskDuplicated) {
    guard copyTask(duplicated.source, as: duplicated.copy, createdOn: duplicated.createdOn, keepingDueDates: true)
    else { return }
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
