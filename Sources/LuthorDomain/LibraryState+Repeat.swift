extension LibraryState {
  /// Applies the events that make a task repeat and make its next occurrence; any other event changes nothing.
  mutating func applyRepeat(_ payload: EventPayload) {
    switch payload {
    case .taskRepeatSet(let set):
      setRepeat(set)
    case .taskRecurred(let recurred):
      recur(recurred)
    default:
      break
    }
  }

  /// Ignores a task that is not open. Completing a task keeps its rule, as it does its due date, so the next
  /// occurrence can copy it.
  private mutating func setRepeat(_ set: TaskRepeatSet) {
    guard openTasks.contains(where: { $0.id == set.taskID }) else { return }
    repeatRules[set.taskID] = set.rule
  }

  /// Makes the open task `recurred.next` out of `recurred.previous`, which is open or completed: in its project
  /// if that is active and in its view, else loose, with its due date, tags and rule. Ignores a task `next`
  /// that exists already, so two devices completing the same task make one next one, and a `previous` that
  /// does not exist.
  private mutating func recur(_ recurred: TaskRecurred) {
    guard captureOrder[recurred.next] == nil,
      let source = openTasks.first(where: { $0.id == recurred.previous })
        ?? completedTasks.first(where: { $0.item.id == recurred.previous })?.item
    else { return }
    captureOrder[recurred.next] = captureOrder.count
    let project = source.projectID.flatMap { projectID in
      projects.firstIndex { $0.id == projectID && $0.viewID == source.viewID }
    }
    let next = TaskItem(
      id: recurred.next, title: source.title, viewID: source.viewID, projectID: project.map { projects[$0].id },
      priority: source.priority, estimate: source.estimate, notes: source.notes)
    insertOpen(next)
    if let project { projects[project].children.append(.task(next)) }
    dueDates[recurred.next] = DueDate(date: recurred.due, isHard: dueDates[recurred.previous]?.isHard ?? false)
    taskTags[recurred.next] = taskTags[recurred.previous]
    repeatRules[recurred.next] = repeatRules[recurred.previous]
  }

  /// How the task repeats; `nil` if it does not.
  public func repeatRule(of taskID: TaskID) -> RepeatRule? {
    repeatRules[taskID]
  }

  /// Whether a task with this ID was ever captured or made by a repeat, open, completed or dropped.
  func hasTask(_ taskID: TaskID) -> Bool {
    captureOrder[taskID] != nil
  }
}
