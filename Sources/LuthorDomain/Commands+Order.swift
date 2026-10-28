// Putting the items of a project in order by hand: one place up or down.
extension Commands {
  /// Moves the item `taskID` `offset` places in the project it is filed in, towards the start for a negative
  /// offset. Moving it past either end, or an item filed in no project, writes nothing.
  public func moveChild(_ taskID: TaskID, by offset: Int, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let state = libraryState(from: log)
    guard let item = state.openItem(taskID) else { throw .noOpenTask(taskID.rawValue) }
    guard let parentID = item.parentID, state.isOpen(parentID) else { return [] }
    var order = state.openChildren(of: parentID).map(\.id)
    guard let from = order.firstIndex(of: taskID) else { throw .noOpenTask(taskID.rawValue) }
    let target = from + offset
    guard order.indices.contains(target), target != from else { return [] }
    order.insert(order.remove(at: from), at: target)
    let event = ChildrenOrdered(parentID: parentID, taskIDs: order)
    return [envelope(EventID(ids.next()), .childrenOrdered(event), log: log)]
  }
}
