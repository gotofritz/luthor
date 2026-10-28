import LuthorDomain

/// The list of one picked priority in the priorities place; `nil` is the list of the tasks with no priority.
public struct PriorityGroup: Equatable, Sendable, Identifiable {
  public let priority: Priority?
  public let tasks: [TaskItem]

  public var id: String { priority?.rawValue ?? "none" }
}

extension LibraryViewModel {
  /// The lists the priorities place shows, one for each priority picked, the most urgent first and no priority
  /// last. A priority with no task still has its list, which takes new ones.
  public var priorityGroups: [PriorityGroup] {
    Self.priorityRows.filter { selectedPriorities.contains($0) }.map { priority in
      let listed = tasks.filter { $0.priority == priority }
      return PriorityGroup(priority: priority, tasks: listed)
    }
  }

  /// The id of the one list the priorities place shows, whatever priorities are picked.
  public static let prioritiesListID = "priorities"

  /// The tasks of every priority picked as one list: by priority, the most urgent first, until a header sorts
  /// them all together.
  public var priorityList: [TaskItem] {
    sorted(priorityGroups.flatMap(\.tasks), inList: Self.prioritiesListID)
  }

  /// Starts a new task with `priority` (or none) from the bottom of that priority's list. The task goes to no
  /// project, so it starts with no estimate; a task begun before is dropped. Nothing is written before OK.
  public func addTask(withPriority priority: Priority?) {
    selection = nil
    editingCard = nil
    projectCardOpen = false
    var item = makeNewItem(under: nil, kind: .task)
    item.card.priority = priority
    item.priorityEdited = true
    newItem = item
  }
}

extension LibraryViewModel {
  /// The date a list shows beside a task: the day it is scheduled for, else its due date.
  public func listedDate(of taskID: TaskID) -> CalendarDate? {
    scheduledDate(of: taskID) ?? dueDate(of: taskID)?.date
  }
}
