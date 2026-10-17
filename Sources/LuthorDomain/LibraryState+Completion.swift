extension LibraryState {
  /// Ignores a task that already exists, open or completed.
  mutating func capture(_ captured: TaskCaptured) {
    guard captureOrder[captured.taskID] == nil else { return }
    captureOrder[captured.taskID] = captureOrder.count
    openTasks.append(TaskItem(id: captured.taskID, title: captured.title, viewID: captured.viewID))
  }

  /// Keeps the task as completed and takes it out of every list. Ignores a task that is not open.
  mutating func complete(_ taskID: TaskID) {
    guard let task = openTasks.first(where: { $0.id == taskID }) else { return }
    completedTasks.append(Completed(item: task, completedWith: nil))
    finish(taskID)
  }

  /// Opens a task completed on its own again, in its project if that is active and in the task's view,
  /// else loose. Ignores a task that is not completed, or that a project's completion took along.
  mutating func reopen(_ taskID: TaskID) {
    guard let index = completedTasks.firstIndex(where: { $0.item.id == taskID && $0.isReopenable }) else { return }
    let task = completedTasks.remove(at: index).item
    let project = task.projectID.flatMap { projectID in
      projects.firstIndex { $0.id == projectID && $0.viewID == task.viewID }
    }
    let reopened = TaskItem(
      id: task.id, title: task.title, viewID: task.viewID, projectID: project.map { projects[$0].id },
      priority: task.priority, estimate: task.estimate)
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
