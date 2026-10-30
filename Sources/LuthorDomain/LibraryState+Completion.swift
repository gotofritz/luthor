/// A task or project that is done or given up, kept so it can be shown and reopened.
public struct Completed<Item: Equatable & Sendable>: Equatable, Sendable {
  public let item: Item
  /// The project whose completion or drop took it along; `nil` if it was completed or dropped itself.
  public let completedWith: TaskID?
  /// Whether it was given up, not completed.
  public let isDropped: Bool
  /// The day it was completed on; `nil` if it was dropped or the log does not say.
  public let completedOn: CalendarDate?

  init(item: Item, completedWith: TaskID?, isDropped: Bool = false, completedOn: CalendarDate? = nil) {
    self.item = item
    self.completedWith = completedWith
    self.isDropped = isDropped
    self.completedOn = completedOn
  }

  /// Only what was completed or dropped itself can be reopened; what a project took along comes back with it.
  public var isReopenable: Bool {
    completedWith == nil
  }
}

extension LibraryState {
  /// Completes the item with the items open in it, all the way down; they come back when it is reopened.
  /// Ignores an item that is not open.
  mutating func complete(_ taskID: TaskID, on day: CalendarDate? = nil) {
    finishTree(of: taskID, on: day) { .completed(with: $0) }
  }

  /// The day a completed task was planned for, remembered when it was completed.
  func plannedDay(of taskID: TaskID) -> CalendarDate? {
    reviewRecords.plannedDays[taskID]
  }

  /// Gives a completed item the day it was done on; an item that is open or was dropped keeps none.
  mutating func date(_ taskID: TaskID, completedOn day: CalendarDate) {
    guard case .completed = items[taskID]?.status else { return }
    completedDays[taskID] = day
  }

  /// Gives the item up with the items open in it, all the way down; they come back when it is reopened.
  /// Ignores an item that is not open.
  mutating func drop(_ taskID: TaskID) {
    finishTree(of: taskID, on: nil) { .dropped(with: $0) }
  }

  private mutating func finishTree(of taskID: TaskID, on day: CalendarDate?, as status: (TaskID?) -> ItemStatus) {
    guard isOpen(taskID) else { return }
    let taken = descendants(of: taskID)
    unfile(taskID)
    finish(taskID, as: status(nil))
    for id in taken { finish(id, as: status(taskID)) }
    for id in [taskID] + taken { completedDays[id] = day }
  }

  /// Takes the item out of every list, keeping it as completed or dropped. A completed task remembers the day
  /// it was planned for, so that day's review can list it as done.
  private mutating func finish(_ id: TaskID, as status: ItemStatus) {
    items[id]?.status = status
    finishedOrder.removeAll { $0 == id }
    finishedOrder.append(id)
    if case .completed = status { reviewRecords.plannedDays[id] = scheduledDates[id] }
    forgetPlanning(of: id)
  }

  /// Opens an item completed or dropped on its own again, with everything that took along. A task goes back to
  /// the day it was done on. It goes back into
  /// its parent if that is open and in the item's view, else it is top-level. Ignores an item that is not
  /// completed or dropped, or that another item's completion or drop took along.
  mutating func reopen(_ taskID: TaskID) {
    guard let stored = items[taskID], stored.status.isReopenable else { return }
    let reopened = [taskID] + finishedOrder.filter { items[$0]?.status.wasTaken(by: taskID) ?? false }
    for id in reopened {
      items[id]?.status = .open
      completedDays[id] = nil
      scheduledDates[id] = reviewRecords.plannedDays.removeValue(forKey: id)
    }
    finishedOrder.removeAll { reopened.contains($0) }
    if let parentID = stored.item.parentID, isOpen(parentID, in: stored.item.viewID) {
      filed[parentID, default: []].append(taskID)
    } else {
      items[taskID]?.item.parentID = nil
    }
  }
}
