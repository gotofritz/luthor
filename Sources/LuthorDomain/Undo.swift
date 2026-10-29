/// What it takes to undo a command and then redo it: the events the command wrote, and the events that take
/// them back. Both are appended as new events, so the log only grows and a replay in any order gives the same state.
public struct UndoStep: Equatable, Sendable {
  /// The events the command wrote, to write again on redo.
  public let forward: [EventPayload]
  /// The events that put back what the command changed, in the order to write them.
  public let backward: [EventPayload]
}

extension LibraryState {
  /// The step that undoes `events`, written when the state was `self`; `nil` if any of them cannot be taken back
  /// (such as a task captured or deleted, or a repeating task's next one), in which case the command is not
  /// undoable. Each inverse restores the value held before, so the undo does not depend on what the event was.
  /// Events that change nothing a user would see (a tag created for a tagging) are left out of both lists.
  public func undoStep(for events: [EventPayload]) -> UndoStep? {
    var working = self
    var forward: [EventPayload] = []
    var inverses: [[EventPayload]] = []
    for (position, event) in events.enumerated() {
      let inverse = working.inverse(of: event)
      // Only a later event reads what this one did, so a single event leaves the state as it is, uncopied.
      if position < events.count - 1 { working.apply(event) }
      switch inverse {
      case .irreversible: return nil
      case .neutral: continue
      case .events(let taken):
        forward.append(event)
        inverses.append(taken)
      }
    }
    guard !forward.isEmpty else { return nil }
    return UndoStep(forward: forward, backward: inverses.reversed().flatMap { $0 })
  }

  /// The events that take `event` back, from the state before it.
  private func inverse(of event: EventPayload) -> Inverse {
    switch event {
    case .tagCreated:
      return .neutral
    case .taskCompleted(let done):
      guard items[done.taskID]?.status.isOpen == true else { return .irreversible }
      return .events([.taskReopened(TaskReopened(taskID: done.taskID))])
    case .taskDropped(let dropped):
      guard items[dropped.taskID]?.status.isOpen == true else { return .irreversible }
      let reopened = EventPayload.taskReopened(TaskReopened(taskID: dropped.taskID))
      // Dropping forgets the day a task was planned for; reopening a dropped task does not bring it back.
      guard let day = scheduledDates[dropped.taskID] else { return .events([reopened]) }
      return .events([reopened, .taskScheduled(TaskScheduled(taskID: dropped.taskID, date: day))])
    case .taskReopened(let reopened):
      guard let stored = items[reopened.taskID] else { return .irreversible }
      switch stored.status {
      case .completed: return .events([.taskCompleted(TaskCompleted(taskID: reopened.taskID))])
      case .dropped: return .events([.taskDropped(TaskDropped(taskID: reopened.taskID))])
      case .open: return .irreversible
      }
    case .taskRenamed(let renamed):
      guard let item = items[renamed.taskID]?.item else { return .irreversible }
      return .events([.taskRenamed(TaskRenamed(taskID: item.id, title: item.title))])
    case .taskPrioritized(let prioritized):
      guard let item = items[prioritized.taskID]?.item else { return .irreversible }
      return .events([.taskPrioritized(TaskPrioritized(taskID: item.id, priority: item.priority))])
    case .taskEstimated(let estimated):
      guard let item = items[estimated.taskID]?.item else { return .irreversible }
      return .events([.taskEstimated(TaskEstimated(taskID: item.id, minutes: item.estimate))])
    case .taskMoved(let moved):
      guard let item = items[moved.taskID]?.item else { return .irreversible }
      return .events([.taskMoved(TaskMoved(taskID: item.id, parentID: item.parentID))])
    case .childrenOrdered(let ordered):
      guard isOpen(ordered.parentID) else { return .irreversible }
      return .events([
        .childrenOrdered(ChildrenOrdered(parentID: ordered.parentID, taskIDs: filed[ordered.parentID] ?? []))
      ])
    case .taskDueSet(let due):
      let before = dueDates[due.taskID]
      let restored = TaskDueSet(taskID: due.taskID, date: before?.date, isHard: before?.isHard ?? false)
      return .events([.taskDueSet(restored)])
    case .tagDeleted(let deleted):
      return tagDeletedInverse(deleted.tagID)
    case .taskTagged(let tagged):
      let had = taskTags[tagged.taskID]?.contains(tagged.tagID) ?? false
      return .events(had ? [] : [.taskUntagged(TaskUntagged(taskID: tagged.taskID, tagID: tagged.tagID))])
    case .taskUntagged(let untagged):
      let had = taskTags[untagged.taskID]?.contains(untagged.tagID) ?? false
      return .events(had ? [.taskTagged(TaskTagged(taskID: untagged.taskID, tagID: untagged.tagID))] : [])
    default:
      return planningInverse(of: event)
    }
  }

  /// The tag made again and put back on the open tasks that carried it; none if a completed task carried it too,
  /// as a completed task cannot be tagged.
  private func tagDeletedInverse(_ tagID: TagID) -> Inverse {
    guard let tag = tagItems.first(where: { $0.id == tagID }) else { return .irreversible }
    let carriers = order.filter { taskTags[$0]?.contains(tagID) ?? false }
    guard carriers.allSatisfy(isOpen) else { return .irreversible }
    let created = EventPayload.tagCreated(TagCreated(tagID: tag.id, name: tag.name, viewID: tag.viewID))
    return .events([created] + carriers.map { .taskTagged(TaskTagged(taskID: $0, tagID: tagID)) })
  }

  /// `inverse(of:)` for the events about the day and who has a task, its repeat and its notes.
  private func planningInverse(of event: EventPayload) -> Inverse {
    switch event {
    case .taskScheduled(let scheduled):
      return .events([daySet(of: scheduled.taskID)])
    case .taskUnscheduled(let unscheduled):
      return .events([daySet(of: unscheduled.taskID)])
    case .taskDelegated(let delegated):
      return .events(delegationSet(of: delegated.taskID) + [daySet(of: delegated.taskID)])
    case .taskReclaimed(let reclaimed):
      return .events(delegationSet(of: reclaimed.taskID))
    case .taskNoted(let noted):
      guard let item = items[noted.taskID]?.item else { return .irreversible }
      return .events([.taskNoted(TaskNoted(taskID: item.id, notes: item.notes))])
    case .taskRepeatSet(let repeating):
      let restored = TaskRepeatSet(taskID: repeating.taskID, rule: repeatRules[repeating.taskID])
      return .events([.taskRepeatSet(restored)])
    default:
      return .irreversible
    }
  }

  /// The event that puts the task back on the day it is planned for now, or off its day.
  private func daySet(of taskID: TaskID) -> EventPayload {
    guard let day = scheduledDates[taskID] else { return .taskUnscheduled(TaskUnscheduled(taskID: taskID)) }
    return .taskScheduled(TaskScheduled(taskID: taskID, date: day))
  }

  /// The event that puts the task back with whoever has it now, or takes it back if no one does.
  private func delegationSet(of taskID: TaskID) -> [EventPayload] {
    guard let held = delegations[taskID] else { return [.taskReclaimed(TaskReclaimed(taskID: taskID))] }
    return [
      .taskDelegated(
        TaskDelegated(taskID: taskID, to: held.person, since: held.since, followUpDate: held.followUpDate))
    ]
  }
}

/// How an event is taken back.
private enum Inverse {
  /// No way: the event is not one a user can undo.
  case irreversible
  /// Nothing to take back, and nothing to write again.
  case neutral
  case events([EventPayload])
}
