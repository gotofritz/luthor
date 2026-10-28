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

  /// Ignores an item that is not open. Completing a task keeps its rule, as it does its due date, so the next
  /// occurrence can copy it.
  private mutating func setRepeat(_ set: TaskRepeatSet) {
    guard isOpen(set.taskID) else { return }
    repeatRules[set.taskID] = set.rule
  }

  /// Makes the open task `recurred.next` out of `recurred.previous`, which is open or completed: in its parent
  /// if that is open and in its view, else loose, with its due date, tags and rule. Ignores a task `next`
  /// that exists already, so two devices completing the same task make one next one, and a `previous` that
  /// does not exist.
  private mutating func recur(_ recurred: TaskRecurred) {
    guard copyTask(recurred.previous, as: recurred.next, createdOn: nil, keepingDueDates: false) else { return }
    dueDates[recurred.next] = DueDate(date: recurred.due, isHard: dueDates[recurred.previous]?.isHard ?? false)
  }

  /// How the task repeats; `nil` if it does not.
  public func repeatRule(of taskID: TaskID) -> RepeatRule? {
    repeatRules[taskID]
  }

  /// The tasks of the view that repeat and were completed, whose next occurrence is open: each series' latest
  /// occurrence done, to show that it was done while the next one waits.
  public func doneOccurrences(in viewID: ViewID) -> [Completed<TaskItem>] {
    view(viewID).completedTasks.filter {
      !$0.isDropped && repeatRules[$0.item.id] != nil && isOpen(TaskID.recurring(after: $0.item.id))
    }
  }

  /// Whether an item with this ID was ever captured or made by a repeat, open, completed or dropped.
  func wasEverTask(_ taskID: TaskID) -> Bool {
    captureOrder[taskID] != nil
  }
}
