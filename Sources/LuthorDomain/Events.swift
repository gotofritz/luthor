/// Captures an item: a task, or with `kind` a project. A task gets a project the same way, by getting its
/// first child.
public struct TaskCaptured: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let title: String
  public let viewID: ViewID
  /// The day it was captured; `nil` for an item captured before cards showed it.
  public let createdOn: CalendarDate?
  /// The item it is filed in; `nil` for a top-level item, as is a parent that is not open or is in another view.
  public let parentID: TaskID?
  /// How it hands out its next actions when it is created as a project; `nil` for a task.
  public let kind: ProjectKind?

  public init(
    taskID: TaskID, title: String, viewID: ViewID, createdOn: CalendarDate? = nil, parentID: TaskID? = nil,
    kind: ProjectKind? = nil
  ) {
    self.taskID = taskID
    self.title = title
    self.viewID = viewID
    self.createdOn = createdOn
    self.parentID = parentID
    self.kind = kind
  }

  /// Events written before views have no `viewID`; they belong to the default view. Events written before
  /// cards showed the day have no `createdOn`.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    taskID = try container.decode(TaskID.self, forKey: .taskID)
    title = try container.decode(String.self, forKey: .title)
    viewID = try container.decodeIfPresent(ViewID.self, forKey: .viewID) ?? .default
    createdOn = try container.decodeIfPresent(CalendarDate.self, forKey: .createdOn)
    parentID = try container.decodeIfPresent(TaskID.self, forKey: .parentID)
    kind = try container.decodeIfPresent(ProjectKind.self, forKey: .kind)
  }
}

public enum EventPayload: Equatable, Sendable {
  case taskCaptured(TaskCaptured)
  case taskCompleted(TaskCompleted)
  case taskReopened(TaskReopened)
  case taskRenamed(TaskRenamed)
  case taskNoted(TaskNoted)
  case taskKindChanged(TaskKindChanged)
  case taskMoved(TaskMoved)
  case viewCreated(ViewCreated)
  case viewRenamed(ViewRenamed)
  case taskMovedToView(TaskMovedToView)
  case taskPrioritized(TaskPrioritized)
  case taskEstimated(TaskEstimated)
  case settingChanged(SettingChanged)
  case taskScheduled(TaskScheduled)
  case taskUnscheduled(TaskUnscheduled)
  case dayPlanOrdered(DayPlanOrdered)
  case dayCapacitySet(DayCapacitySet)
  case dayHoursSet(DayHoursSet)
  case taskStartSet(TaskStartSet)
  case dayBlockSet(DayBlockSet)
  case dayBlockRemoved(DayBlockRemoved)
  case taskSessionSet(TaskSessionSet)
  case taskSessionRemoved(TaskSessionRemoved)
  case taskDelegated(TaskDelegated)
  case taskReclaimed(TaskReclaimed)
  case taskDropped(TaskDropped)
  case taskDueSet(TaskDueSet)
  case tagCreated(TagCreated)
  case taskTagged(TaskTagged)
  case taskUntagged(TaskUntagged)
  case taskTimeLogged(TaskTimeLogged)
  case unplannedTimeLogged(UnplannedTimeLogged)
  case dayReviewed(DayReviewed)
  case reviewDefaultSet(ReviewDefaultSet)
  case reviewIntervalSet(ReviewIntervalSet)
  case reviewDateSet(ReviewDateSet)
  case taskReviewed(TaskReviewed)
  case taskRepeatSet(TaskRepeatSet)
  case taskRecurred(TaskRecurred)
  case taskDuplicated(TaskDuplicated)
  case taskDeleted(TaskDeleted)
  case childrenOrdered(ChildrenOrdered)
  case tagDeleted(TagDeleted)
}

/// One entry in the event log: a payload plus the metadata replay orders by.
public struct EventEnvelope: Equatable, Sendable {
  public let id: EventID
  public let deviceID: DeviceID
  /// Lamport counter; the primary ordering key.
  public let lamport: UInt64
  public let payload: EventPayload

  public init(id: EventID, deviceID: DeviceID, lamport: UInt64, payload: EventPayload) {
    self.id = id
    self.deviceID = deviceID
    self.lamport = lamport
    self.payload = payload
  }
}

/// Completes an item. A project takes the items still open in it along, all the way down.
public struct TaskCompleted: Equatable, Codable, Sendable {
  public let taskID: TaskID

  public init(taskID: TaskID) {
    self.taskID = taskID
  }
}

/// Brings a completed or dropped item back with everything its completion or drop took along. It goes back
/// into its parent if that is still open and in its view, else it is top-level.
public struct TaskReopened: Equatable, Codable, Sendable {
  public let taskID: TaskID

  public init(taskID: TaskID) {
    self.taskID = taskID
  }
}

/// How a project hands out its next actions.
public enum ProjectKind: String, Codable, Sendable {
  /// Every open task can be worked on at once.
  case parallel
  /// Only the first open task can be worked on; the rest wait their turn.
  case sequential
}

/// Gives an open item another title.
public struct TaskRenamed: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let title: String

  public init(taskID: TaskID, title: String) {
    self.taskID = taskID
    self.title = title
  }
}

/// Sets the notes of an open item, or with none clears them. Notes are plain text.
public struct TaskNoted: Equatable, Codable, Sendable {
  public let taskID: TaskID
  /// The notes from now on; `nil` clears them.
  public let notes: String?

  public init(taskID: TaskID, notes: String?) {
    self.taskID = taskID
    self.notes = notes
  }
}

/// Makes an open item a sequential or a parallel project. A task it is applied to becomes a project. With no
/// kind it makes a project a task again.
public struct TaskKindChanged: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let kind: ProjectKind?

  public init(taskID: TaskID, kind: ProjectKind?) {
    self.taskID = taskID
    self.kind = kind
  }
}

/// Files an open item in another open item of its view, at the end of that item's children, which makes it a
/// project; or with no parent makes the item top-level. Ignored for an item or a parent that is not open, a
/// parent in another view, a parent in the item's own subtree, and an item already there.
public struct TaskMoved: Equatable, Codable, Sendable {
  public let taskID: TaskID
  /// The item it is filed in from now on; `nil` makes it top-level.
  public let parentID: TaskID?

  public init(taskID: TaskID, parentID: TaskID?) {
    self.taskID = taskID
    self.parentID = parentID
  }
}

public struct ViewCreated: Equatable, Codable, Sendable {
  public let viewID: ViewID
  public let name: String

  public init(viewID: ViewID, name: String) {
    self.viewID = viewID
    self.name = name
  }
}

public struct ViewRenamed: Equatable, Codable, Sendable {
  public let viewID: ViewID
  public let name: String

  public init(viewID: ViewID, name: String) {
    self.viewID = viewID
    self.name = name
  }
}

/// Takes an item across to another view, out of its parent and into that view's inbox, together with the items
/// open in it.
public struct TaskMovedToView: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let viewID: ViewID

  public init(taskID: TaskID, viewID: ViewID) {
    self.taskID = taskID
    self.viewID = viewID
  }
}

/// How much a task matters. Importance only: never order, deadline or day.
public enum Priority: String, Codable, Sendable, CaseIterable {
  /// A: must be addressed today.
  case critical = "A"
  /// B: meaningfully advances what matters.
  case important = "B"
  /// C: do when capacity remains.
  case optional = "C"
  /// Not committed to; kept for one day.
  case someday
}

/// Gives an open task a priority, or with none clears it.
public struct TaskPrioritized: Equatable, Codable, Sendable {
  public let taskID: TaskID
  /// The priority from now on; `nil` clears it.
  public let priority: Priority?

  public init(taskID: TaskID, priority: Priority?) {
    self.taskID = taskID
    self.priority = priority
  }
}

/// Gives an open task an estimate in minutes, or with none clears it.
public struct TaskEstimated: Equatable, Codable, Sendable {
  public let taskID: TaskID
  /// Minutes the task is expected to take; `nil` clears it.
  public let minutes: Int?

  public init(taskID: TaskID, minutes: Int?) {
    self.taskID = taskID
    self.minutes = minutes
  }
}

/// Changes one setting: global with no `viewID`, or an override for one view's `viewID`. `value` of
/// `nil` clears it, falling back to the global value (or, globally, to the built-in default).
public struct SettingChanged: Equatable, Codable, Sendable {
  /// The setting's raw key, as written to the log. A key `LibraryState.apply(_:)` does not recognise is
  /// ignored rather than failing the line, so an old build survives a log a newer one wrote.
  public let key: String
  public let value: String?
  public let viewID: ViewID?

  public init(key: SettingKey, value: String?, viewID: ViewID? = nil) {
    self.key = key.rawValue
    self.value = value
    self.viewID = viewID
  }
}

extension EventEnvelope {
  /// Total order for replay: Lamport counter, then device ID, then event ID.
  public static func replayOrder(_ lhs: EventEnvelope, _ rhs: EventEnvelope) -> Bool {
    (lhs.lamport, lhs.deviceID, lhs.id) < (rhs.lamport, rhs.deviceID, rhs.id)
  }
}
