/// How the children of a project are sorted.
public enum ChildSort: Equatable, Sendable {
  /// By title, ignoring case.
  case title(ascending: Bool)
  /// A first, then B, C, items with no priority, and someday last.
  case priority
}

// Putting the items of a project in order: sorted, or moved one place.
extension Commands {
  /// Sorts the items filed in the project `projectID`; items that compare equal keep their order. Sorting what
  /// is in that order already writes nothing.
  public func sortChildren(of projectID: TaskID, by sort: ChildSort, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let state = libraryState(from: log)
    guard state.isOpen(projectID), state.hasProject(projectID) else { throw .unknownProject(projectID) }
    let children = state.openChildren(of: projectID)
    let sorted = children.enumerated().sorted { lhs, rhs in
      let result = Self.compare(lhs.element, rhs.element, by: sort)
      return result == .orderedSame ? lhs.offset < rhs.offset : result == .orderedAscending
    }.map(\.element)
    return try orderChildren(of: projectID, as: sorted.map(\.id), log: log)
  }

  /// Moves the item `taskID` `offset` places in the project it is filed in, towards the start for a negative
  /// offset. Moving it past either end, or an item filed in no project, writes nothing.
  public func moveChild(_ taskID: TaskID, by offset: Int, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let state = libraryState(from: log)
    guard let item = state.openItem(taskID) else { throw .noOpenTask(taskID.rawValue) }
    guard let parentID = item.parentID, state.isOpen(parentID) else { return [] }
    var ids = state.openChildren(of: parentID).map(\.id)
    guard let from = ids.firstIndex(of: taskID) else { throw .noOpenTask(taskID.rawValue) }
    let target = from + offset
    guard ids.indices.contains(target), target != from else { return [] }
    ids.insert(ids.remove(at: from), at: target)
    return try orderChildren(of: parentID, as: ids, log: log)
  }

  private func orderChildren(of projectID: TaskID, as taskIDs: [TaskID], log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    guard libraryState(from: log).openChildren(of: projectID).map(\.id) != taskIDs else { return [] }
    let event = ChildrenOrdered(parentID: projectID, taskIDs: taskIDs)
    return [envelope(EventID(ids.next()), .childrenOrdered(event), log: log)]
  }

  private static func compare(_ lhs: TaskItem, _ rhs: TaskItem, by sort: ChildSort) -> ComparisonResult {
    switch sort {
    case .title(let ascending):
      let left = lhs.title.lowercased()
      let right = rhs.title.lowercased()
      if left == right { return .orderedSame }
      return (left < right) == ascending ? .orderedAscending : .orderedDescending
    case .priority:
      let left = rank(lhs.priority)
      let right = rank(rhs.priority)
      return left == right ? .orderedSame : (left < right ? .orderedAscending : .orderedDescending)
    }
  }

  private static func rank(_ priority: Priority?) -> Int {
    switch priority {
    case .critical: 0
    case .important: 1
    case .optional: 2
    case nil: 3
    case .someday: 4
    }
  }
}

/// The outcome of comparing two items; the domain imports nothing, so not Foundation's.
private enum ComparisonResult {
  case orderedAscending, orderedSame, orderedDescending
}
