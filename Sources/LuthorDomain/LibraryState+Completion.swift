/// A task or project that is done, kept so it can be shown and reopened.
public struct Completed<Item: Equatable & Sendable>: Equatable, Sendable {
  public let item: Item
  /// The project whose completion took it along; `nil` if it was completed itself.
  public let completedWith: ProjectID?

  /// Only what was completed itself can be reopened; what a project took along comes back with it.
  public var isReopenable: Bool {
    completedWith == nil
  }
}

extension LibraryState {
  /// Applies the events that complete a task or bring a completed task or project back; any other event
  /// changes nothing.
  mutating func applyCompletion(_ payload: EventPayload) {
    switch payload {
    case .taskCompleted(let completed):
      complete(completed.taskID)
    case .taskReopened(let reopened):
      reopen(reopened.taskID)
    case .projectReopened(let reopened):
      reopen(reopened.projectID)
    default:
      break
    }
  }

  /// Ignores a task that already exists, open or completed.
  mutating func capture(_ captured: TaskCaptured) {
    guard captureOrder[captured.taskID] == nil else { return }
    captureOrder[captured.taskID] = captureOrder.count
    openTasks.append(
      TaskItem(
        id: captured.taskID, title: captured.title, viewID: captured.viewID, createdOn: captured.createdOn))
  }

  /// Keeps the task as completed and takes it out of every list. Ignores a task that is not open.
  mutating func complete(_ taskID: TaskID) {
    guard let task = openTasks.first(where: { $0.id == taskID }) else { return }
    completedTasks.append(Completed(item: task, completedWith: nil))
    reviewRecords.plannedDays[taskID] = scheduledDates[taskID]
    finish(taskID)
  }

  /// Opens a task completed on its own again, in its project if that is active and in the task's view,
  /// else loose. Ignores a task that is not completed, or that a project's completion took along.
  mutating func reopen(_ taskID: TaskID) {
    guard let index = completedTasks.firstIndex(where: { $0.item.id == taskID && $0.isReopenable }) else { return }
    var reopened = completedTasks.remove(at: index).item
    reviewRecords.plannedDays.removeValue(forKey: taskID)
    let project = reopened.projectID.flatMap { projectID in
      projects.firstIndex { $0.id == projectID && $0.viewID == reopened.viewID }
    }
    reopened.projectID = project.map { projects[$0].id }
    insertOpen(reopened)
    if let project { projects[project].children.append(.task(reopened)) }
  }

  /// Adds an open task where its capture order puts it.
  mutating func insertOpen(_ task: TaskItem) {
    let rank = captureOrder[task.id] ?? Int.max
    let position = openTasks.firstIndex { (captureOrder[$0.id] ?? Int.max) > rank } ?? openTasks.endIndex
    openTasks.insert(task, at: position)
  }

  /// Keeps a project, its sub-projects and their open tasks as completed, the project first. Only the
  /// project is completed itself; the rest were taken along.
  mutating func keepCompleted(_ projectID: ProjectID, subtree: Set<ProjectID>) {
    guard let root = projects.first(where: { $0.id == projectID }) else { return }
    completedProjects.append(Completed(item: root, completedWith: nil))
    for project in projects where subtree.contains(project.id) && project.id != projectID {
      completedProjects.append(Completed(item: project, completedWith: projectID))
    }
    for task in openTasks where task.projectID.map(subtree.contains) ?? false {
      completedTasks.append(Completed(item: task, completedWith: projectID))
      reviewRecords.plannedDays[task.id] = scheduledDates[task.id]
    }
  }

  /// Opens a project completed on its own again, with everything its completion took along. It goes back
  /// into the project it was nested in if that is active and in its view, else it is top-level. Ignores a
  /// project that is not completed, or that another project's completion took along.
  mutating func reopen(_ projectID: ProjectID) {
    guard let root = completedProjects.first(where: { $0.item.id == projectID && $0.isReopenable }) else { return }
    let taken = completedProjects.filter { $0.item.id == projectID || $0.completedWith == projectID }
    completedProjects.removeAll { entry in taken.contains(entry) }
    let tasks = completedTasks.filter { $0.completedWith == projectID }
    completedTasks.removeAll { entry in tasks.contains(entry) }
    for task in tasks { reviewRecords.plannedDays.removeValue(forKey: task.item.id) }
    projects += taken.map(\.item)
    for task in tasks.map(\.item) { insertOpen(task) }
    let parent = root.item.parentID.flatMap { parentID in
      projects.firstIndex { $0.id == parentID && $0.viewID == root.item.viewID }
    }
    if let parent {
      projects[parent].children.append(.project(projectID))
    } else if let index = projects.firstIndex(where: { $0.id == projectID }) {
      projects[index].parentID = nil
    }
  }
}
