/// What a bulk edit does to one field of every task: nothing, or sets it.
public enum FieldChange<Value: Equatable & Sendable>: Equatable, Sendable {
  case keep
  case set(Value)
}

/// What the edit card of several tasks writes to all of them. A field left at `keep` is not touched.
public struct BulkEdit: Equatable, Sendable {
  public var priority: FieldChange<Priority?>
  public var estimate: FieldChange<Int?>
  public var due: FieldChange<DueDate?>
  /// The project the tasks are filed in; `.set(nil)` takes them out of their project.
  public var project: FieldChange<TaskID?>
  /// The day the tasks are planned for; `.set(nil)` takes them off their day.
  public var scheduled: FieldChange<CalendarDate?>
  public var repeatRule: FieldChange<RepeatRule?>
  /// A note added, as a bullet after the notes each task has.
  public var addNote: String
  /// Names of tags to put on every task, created in the view if it lacks them.
  public var addTags: [String]
  public var removeTags: [TagID]

  public init(
    priority: FieldChange<Priority?> = .keep,
    estimate: FieldChange<Int?> = .keep,
    due: FieldChange<DueDate?> = .keep,
    project: FieldChange<TaskID?> = .keep,
    scheduled: FieldChange<CalendarDate?> = .keep,
    repeatRule: FieldChange<RepeatRule?> = .keep,
    addNote: String = "",
    addTags: [String] = [],
    removeTags: [TagID] = []
  ) {
    self.priority = priority
    self.estimate = estimate
    self.due = due
    self.project = project
    self.scheduled = scheduled
    self.repeatRule = repeatRule
    self.addNote = addNote
    self.addTags = addTags
    self.removeTags = removeTags
  }
}

/// What several tasks hold in a field: the one value they all have, or that they differ.
public enum Common<Value: Equatable & Sendable>: Equatable, Sendable {
  case same(Value)
  case mixed

  init(_ values: [Value]) {
    guard let first = values.first, values.allSatisfy({ $0 == first }) else {
      self = .mixed
      return
    }
    self = .same(first)
  }
}

/// The fields of several selected tasks, each shown only where all of them agree.
public struct BulkSummary: Equatable, Sendable {
  /// The open tasks among those asked about, in the order asked.
  public let taskIDs: [TaskID]
  public let priority: Common<Priority?>
  public let estimate: Common<Int?>
  public let due: Common<DueDate?>
  public let project: Common<TaskID?>
  public let scheduled: Common<CalendarDate?>
  public let repeatRule: Common<RepeatRule?>
  /// The notes, when every task has the same.
  public let notes: Common<String?>
  /// The tags every task carries, and those only some do.
  public let commonTags: [TagItem]
  public let partialTags: [TagItem]

  public var count: Int { taskIDs.count }
}

extension LibraryState {
  /// What the open tasks among `ids` hold in common. Projects, and tasks that are not open, are left out.
  public func bulkSummary(of ids: [TaskID]) -> BulkSummary {
    let tasks = ids.compactMap { id in openItem(id).flatMap { $0.kind == nil ? $0 : nil } }
    let carried = tasks.map { Set(tags(of: $0.id).map(\.id)) }
    let all = carried.dropFirst().reduce(carried.first ?? []) { $0.intersection($1) }
    let some = carried.reduce(into: Set<TagID>()) { $0.formUnion($1) }.subtracting(all)
    return BulkSummary(
      taskIDs: tasks.map(\.id),
      priority: Common(tasks.map(\.priority)),
      estimate: Common(tasks.map(\.estimate)),
      due: Common(tasks.map { dueDate(of: $0.id) }),
      project: Common(tasks.map(\.parentID)),
      scheduled: Common(tasks.map { scheduledDate(of: $0.id) }),
      repeatRule: Common(tasks.map { repeatRule(of: $0.id) }),
      notes: Common(tasks.map(\.notes)),
      commonTags: tagItems.filter { all.contains($0.id) },
      partialTags: tagItems.filter { some.contains($0.id) })
  }
}

extension Commands {
  /// Applies `edit` to each open task of `taskIDs`, one after another, so a task that already holds a value writes
  /// nothing for it. A task that is not open stops the whole edit.
  public func bulkEdit(_ edit: BulkEdit, taskIDs: [TaskID], log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    var events: [EventEnvelope] = []
    for taskID in taskIDs {
      if case .set(let priority) = edit.priority {
        events += try prioritize(taskID: taskID, as: priority, log: log + events)
      }
      if case .set(let minutes) = edit.estimate {
        events += try estimate(taskID: taskID, as: minutes, log: log + events)
      }
      events += try planFields(edit, taskID: taskID, log: log + events)
      if case .set(let projectID) = edit.project {
        events += try move(taskID: taskID, to: projectID, log: log + events)
      }
      for name in edit.addTags { events += try tag(taskID: taskID, named: name, log: log + events) }
      for tagID in edit.removeTags { events += try untag(taskID: taskID, from: tagID, log: log + events) }
    }
    return events
  }

  /// The events that set the due date, the day and the repeat of one task. They are in one place because a repeat
  /// and a due date depend on each other.
  private func planFields(_ edit: BulkEdit, taskID: TaskID, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    var events: [EventEnvelope] = []
    if case .set(let due) = edit.due {
      // As clearing one due date does: a repeat with no due date to count from counts from completion.
      if due == nil, let rule = libraryState(from: log + events).repeatRule(of: taskID) {
        events += try setRepeat(taskID: taskID, to: rule.countingFromCompletion, dueIfNone: nil, log: log + events)
      }
      events += try setDue(taskID: taskID, to: due?.date, isHard: due?.isHard ?? false, log: log + events)
    }
    if case .set(let day) = edit.scheduled {
      if let day {
        events += try schedule(taskID: taskID, on: day, log: log + events)
      } else {
        events += try unschedule(taskID: taskID, log: log + events)
      }
    }
    if case .set(let rule) = edit.repeatRule {
      let hasDue = libraryState(from: log + events).dueDate(of: taskID) != nil
      events += try setRepeat(
        taskID: taskID, to: hasDue ? rule : rule?.countingFromCompletion, dueIfNone: nil, log: log + events)
    }
    if !edit.addNote.isEmpty { events += try appendNote(taskID: taskID, edit.addNote, log: log + events) }
    return events
  }

  /// Drops each open task of `taskIDs`.
  public func drop(taskIDs: [TaskID], log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    var events: [EventEnvelope] = []
    for taskID in taskIDs { events += try drop(taskID: taskID, log: log + events) }
    return events
  }

  /// Deletes each task of `taskIDs` for good.
  public func delete(taskIDs: [TaskID], log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    var events: [EventEnvelope] = []
    for taskID in taskIDs { events += try delete(taskID: taskID, log: log + events) }
    return events
  }
}
