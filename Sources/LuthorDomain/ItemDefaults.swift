/// The priority and estimate a new item starts with; `nil` for none.
public struct ItemDefaults: Equatable, Sendable {
  public let priority: Priority?
  public let estimate: Int?

  public init(priority: Priority?, estimate: Int?) {
    self.priority = priority
    self.estimate = estimate
  }
}

extension ItemDefaults {
  public static let none = ItemDefaults(priority: nil, estimate: nil)
}

extension LibraryState {
  /// What a new task under `parentID` starts with: the priority of the nearest project above it that has one,
  /// and the estimate of the nearest that has one, all the way up to the root project. A task in no project
  /// starts with neither.
  public func defaults(forNewTaskUnder parentID: TaskID?) -> ItemDefaults {
    var priority: Priority?
    var estimate: Int?
    var current = parentID
    var visited: Set<TaskID> = []
    while let id = current, visited.insert(id).inserted, let item = items[id]?.item {
      priority = priority ?? item.priority
      estimate = estimate ?? item.estimate
      current = item.parentID
    }
    return ItemDefaults(priority: priority, estimate: estimate)
  }

  /// What a new project under `parentID` in the view `viewID` starts with: for a top-level project the ones set
  /// in settings, none by default; a sub-project starts with neither.
  public func defaults(forNewProjectUnder parentID: TaskID?, in viewID: ViewID) -> ItemDefaults {
    guard parentID == nil else { return .none }
    let settings = settings(for: viewID)
    return ItemDefaults(priority: settings.defaultProjectPriority, estimate: settings.defaultProjectEstimate)
  }
}
