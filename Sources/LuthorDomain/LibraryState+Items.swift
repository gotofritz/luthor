// The items: how capturing, filing and moving change them, and the lists of open and finished tasks and
// projects that are read from them. A task and a project are the same kind of item; an item with `kind`
// set is a project. In its own file (SwiftLint file_length) rather than suppressed.
extension LibraryState {
  /// The open tasks of every view, the items that are not projects, in capture order.
  var openTasks: [TaskItem] {
    order.compactMap { id in
      guard let stored = items[id], stored.status.isOpen, stored.item.kind == nil else { return nil }
      return stored.item
    }
  }

  /// The open projects of every view, in capture order.
  var projects: [Project] {
    order.compactMap { id in
      guard let stored = items[id], stored.status.isOpen, stored.item.kind != nil else { return nil }
      return project(stored.item)
    }
  }

  /// The completed and dropped tasks of every view, in the order they were.
  var completedTasks: [Completed<TaskItem>] {
    finishedItems(projects: false) { $0 }
  }

  /// The completed and dropped projects of every view, in the order they were.
  var completedProjects: [Completed<Project>] {
    finishedItems(projects: true) { project($0) }
  }

  private func finishedItems<Item: Equatable & Sendable>(
    projects wanted: Bool,
    as make: (TaskItem) -> Item
  ) -> [Completed<Item>] {
    finishedOrder.compactMap { id -> Completed<Item>? in
      guard let stored = items[id], (stored.item.kind != nil) == wanted else { return nil }
      switch stored.status {
      case .open: return nil
      case .completed(let root): return Completed(item: make(stored.item), completedWith: root)
      case .dropped(let root): return Completed(item: make(stored.item), completedWith: root, isDropped: true)
      }
    }
  }

  /// The project an item stands for, with what is filed in it.
  func project(_ item: TaskItem) -> Project {
    let children = (filed[item.id] ?? []).compactMap { childID -> ProjectChild? in
      guard let child = items[childID]?.item else { return nil }
      return child.kind == nil ? .task(child) : .project(childID)
    }
    return Project(
      id: item.id, title: item.title, kind: item.kind ?? .parallel, viewID: item.viewID, parentID: item.parentID,
      children: children, notes: item.notes, createdOn: item.createdOn,
      priority: item.priority, estimate: item.estimate)
  }

  /// Whether the item exists and is open.
  func isOpen(_ id: TaskID) -> Bool {
    items[id]?.status.isOpen ?? false
  }

  /// Whether the item is open and in this view.
  func isOpen(_ id: TaskID, in viewID: ViewID) -> Bool {
    guard let stored = items[id] else { return false }
    return stored.status.isOpen && stored.item.viewID == viewID
  }

  /// The open item, a task or a project; `nil` for one that is not open.
  func openItem(_ id: TaskID) -> TaskItem? {
    items[id].flatMap { $0.status.isOpen ? $0.item : nil }
  }

  /// The task if it is open or completed; `nil` for a project, a dropped task and one that does not exist.
  func existingTask(_ id: TaskID) -> TaskItem? {
    guard let stored = items[id], stored.item.kind == nil else { return nil }
    switch stored.status {
    case .open, .completed: return stored.item
    case .dropped: return nil
    }
  }

  /// The item if it is open or completed, a task or a project; `nil` for one that was given up or does not exist.
  func existingItem(_ id: TaskID) -> TaskItem? {
    guard let stored = items[id] else { return nil }
    switch stored.status {
    case .open, .completed: return stored.item
    case .dropped: return nil
    }
  }

  /// The item and every item open in it, at any depth; empty for an item that is not open.
  func subtree(of id: TaskID) -> Set<TaskID> {
    guard isOpen(id) else { return [] }
    return Set([id] + descendants(of: id))
  }

  /// The items filed in the item, at any depth, in capture order. An item completed on its own is not among
  /// them, as it is no longer filed.
  func descendants(of id: TaskID) -> [TaskID] {
    var found: [TaskID] = []
    var pending = [id]
    while let current = pending.popLast() {
      for child in filed[current] ?? [] where isOpen(child) {
        found.append(child)
        pending.append(child)
      }
    }
    return found.sorted { (captureOrder[$0] ?? Int.max) < (captureOrder[$1] ?? Int.max) }
  }

  /// Ignores an item that already exists, open, completed or dropped. Under a parent that is not open or is in
  /// another view, the item is top-level.
  mutating func capture(_ captured: TaskCaptured) {
    guard captureOrder[captured.taskID] == nil else { return }
    captureOrder[captured.taskID] = captureOrder.count
    order.append(captured.taskID)
    let item = TaskItem(
      id: captured.taskID, title: captured.title, viewID: captured.viewID, createdOn: captured.createdOn,
      kind: captured.kind)
    items[captured.taskID] = StoredItem(item: item, status: .open)
    if let parentID = captured.parentID, isOpen(parentID, in: captured.viewID) {
      file(captured.taskID, under: parentID)
    }
  }

  /// Files the item at the end of the parent's children. An item that gets a first child is a project.
  mutating func file(_ id: TaskID, under parentID: TaskID) {
    items[id]?.item.parentID = parentID
    filed[parentID, default: []].append(id)
    if items[parentID]?.item.kind == nil { items[parentID]?.item.kind = .parallel }
  }

  /// Takes the item out of its parent's children. It keeps the parent it had, so reopening it can go back.
  mutating func unfile(_ id: TaskID) {
    guard let parentID = items[id]?.item.parentID else { return }
    filed[parentID]?.removeAll { $0 == id }
    if filed[parentID]?.isEmpty == true { filed[parentID] = nil }
  }

  /// Files the item in the parent, or with no parent makes it top-level, at the end of its new parent's
  /// children. Ignores an item or a parent that is not open, a parent in another view, a parent in the item's
  /// own subtree, and an item already there.
  mutating func move(_ moved: TaskMoved) {
    guard let stored = items[moved.taskID], stored.status.isOpen, stored.item.parentID != moved.parentID else {
      return
    }
    guard let parentID = moved.parentID else {
      unfile(moved.taskID)
      items[moved.taskID]?.item.parentID = nil
      return
    }
    guard isOpen(parentID, in: stored.item.viewID), !subtree(of: moved.taskID).contains(parentID) else { return }
    unfile(moved.taskID)
    file(moved.taskID, under: parentID)
  }

  /// Takes the item across with the items open in it; it leaves its parent and is top-level there. Planning
  /// and tags are of one view, so they are let go. Ignores an item that is not open and a view that does not
  /// exist.
  mutating func move(_ taskID: TaskID, toView viewID: ViewID) {
    guard isOpen(taskID), hasView(viewID) else { return }
    let moved = [taskID] + descendants(of: taskID)
    unfile(taskID)
    items[taskID]?.item.parentID = nil
    for id in moved {
      items[id]?.item.viewID = viewID
      forgetPlanning(of: id)
      taskTags.removeValue(forKey: id)
    }
  }

  /// Changes the open item with `change`. Ignores an item that is not open.
  mutating func updateItem(_ id: TaskID, _ change: (inout TaskItem) -> Void) {
    guard var stored = items[id], stored.status.isOpen else { return }
    change(&stored.item)
    items[id] = stored
  }
}
