// Duplicating a task, deleting a task or a project for good, and turning a task into a project. In their own
// file (SwiftLint file_length) rather than suppressed.
extension LibraryState {
  /// Applies the events that duplicate, delete or promote; any other event changes nothing.
  mutating func applyStructure(_ payload: EventPayload) {
    switch payload {
    case .taskDuplicated(let duplicated):
      duplicate(duplicated)
    case .taskDeleted(let deleted):
      delete(deleted.taskID)
    case .projectDeleted(let deleted):
      delete(deleted.projectID)
    case .taskPromoted(let promoted):
      promote(promoted)
    default:
      break
    }
  }

  /// Makes the open task `copyID` out of the task `sourceID`, which is open or completed: in its project if
  /// that is active and in its view, else loose, with its title, notes, priority, estimate, tags and rule.
  /// Returns whether it did; it does not for a `copyID` that exists already, so two devices making the same
  /// copy make one, nor for a `sourceID` that does not exist.
  mutating func copyTask(_ sourceID: TaskID, as copyID: TaskID, createdOn: CalendarDate?) -> Bool {
    guard captureOrder[copyID] == nil,
      let source = openTasks.first(where: { $0.id == sourceID })
        ?? completedTasks.first(where: { $0.item.id == sourceID })?.item
    else { return false }
    captureOrder[copyID] = captureOrder.count
    let project = source.projectID.flatMap { projectID in
      projects.firstIndex { $0.id == projectID && $0.viewID == source.viewID }
    }
    let copy = TaskItem(
      id: copyID, title: source.title, viewID: source.viewID, projectID: project.map { projects[$0].id },
      priority: source.priority, estimate: source.estimate, notes: source.notes, createdOn: createdOn)
    insertOpen(copy)
    if let project { projects[project].children.append(.task(copy)) }
    taskTags[copyID] = taskTags[sourceID]
    repeatRules[copyID] = repeatRules[sourceID]
    return true
  }

  /// Whether the project exists: active, dropped or completed, but not deleted.
  func hasProject(_ projectID: ProjectID) -> Bool {
    projects.contains(where: { $0.id == projectID }) || completedProjects.contains(where: { $0.item.id == projectID })
  }

  /// Copies the task, and its due date with it.
  private mutating func duplicate(_ duplicated: TaskDuplicated) {
    guard copyTask(duplicated.source, as: duplicated.copy, createdOn: duplicated.createdOn) else { return }
    dueDates[duplicated.copy] = dueDates[duplicated.source]
  }

  /// Takes a task, open or completed, out of every list and forgets what was set on it. Its place in the
  /// capture order stays, so capturing it again or reopening it brings nothing back. Ignores a task that does
  /// not exist.
  private mutating func delete(_ taskID: TaskID) {
    finish(taskID)
    completedTasks.removeAll { $0.item.id == taskID }
    dueDates.removeValue(forKey: taskID)
    repeatRules.removeValue(forKey: taskID)
    taskTags.removeValue(forKey: taskID)
    reviewRecords.plannedDays.removeValue(forKey: taskID)
    reviewRecords.taskMinutes = reviewRecords.taskMinutes.filter { $0.key.taskID != taskID }
  }

  /// Takes a project, active, dropped or completed, out of every list with every project nested in it and
  /// every task in them, open or completed. Ignores a project that does not exist.
  private mutating func delete(_ projectID: ProjectID) {
    let doomed = family(of: projectID)
    guard !doomed.isEmpty else { return }
    let taskIDs =
      openTasks.filter { $0.projectID.map(doomed.contains) ?? false }.map(\.id)
      + completedTasks.filter { $0.item.projectID.map(doomed.contains) ?? false }.map(\.item.id)
    for taskID in taskIDs { delete(taskID) }
    if let parentID = projects.first(where: { $0.id == projectID })?.parentID {
      updateProject(parentID) { parent in parent.children.removeAll { $0 == .project(projectID) } }
    }
    projects.removeAll { doomed.contains($0.id) }
    completedProjects.removeAll { doomed.contains($0.item.id) }
    for id in doomed {
      projectReviews.intervals.removeValue(forKey: id)
      projectReviews.reviewedOn.removeValue(forKey: id)
    }
  }

  /// The project and every project nested in it at any depth, active or completed; empty for a project that
  /// is neither.
  private func family(of projectID: ProjectID) -> Set<ProjectID> {
    let nesting =
      projects.map { (id: $0.id, parentID: $0.parentID) }
      + completedProjects.map { (id: $0.item.id, parentID: $0.item.parentID) }
    guard nesting.contains(where: { $0.id == projectID }) else { return [] }
    var found: Set<ProjectID> = [projectID]
    var grew = true
    while grew {
      let size = found.count
      for (id, parentID) in nesting {
        if let parentID, found.contains(parentID) { found.insert(id) }
      }
      grew = found.count > size
    }
    return found
  }

  /// Makes the open task a parallel project with the same title, notes, view and day created, in the project
  /// the task was filed in and at its place there, and takes the task away. Ignores a task that is not open and
  /// a project ID that is in use.
  private mutating func promote(_ promoted: TaskPromotedToProject) {
    guard let task = openTasks.first(where: { $0.id == promoted.taskID }),
      !projects.contains(where: { $0.id == promoted.projectID }),
      !completedProjects.contains(where: { $0.item.id == promoted.projectID })
    else { return }
    projects.append(
      Project(
        id: promoted.projectID, title: task.title, kind: .parallel, viewID: task.viewID, parentID: task.projectID,
        notes: task.notes, createdOn: task.createdOn))
    if let parentID = task.projectID {
      updateProject(parentID) { parent in
        let position = parent.children.firstIndex { child in
          guard case .task(let filed) = child else { return false }
          return filed.id == promoted.taskID
        }
        if let position {
          parent.children[position] = .project(promoted.projectID)
        } else {
          parent.children.append(.project(promoted.projectID))
        }
      }
    }
    delete(promoted.taskID)
  }
}
