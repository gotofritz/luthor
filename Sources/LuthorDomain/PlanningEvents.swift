/// Plans a task for a day. Scheduling it again moves it: the task keeps its identity.
public struct TaskScheduled: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let date: CalendarDate

  public init(taskID: TaskID, date: CalendarDate) {
    self.taskID = taskID
    self.date = date
  }
}

/// Takes a task off the day it was planned for.
public struct TaskUnscheduled: Equatable, Codable, Sendable {
  public let taskID: TaskID

  public init(taskID: TaskID) {
    self.taskID = taskID
  }
}

/// Sets the manual order of one view's plan for a day. Tasks planned for the day after it follow it;
/// tasks it names that are no longer planned for the day are skipped.
public struct DayPlanOrdered: Equatable, Codable, Sendable {
  public let viewID: ViewID
  public let date: CalendarDate
  public let taskIDs: [TaskID]

  public init(viewID: ViewID, date: CalendarDate, taskIDs: [TaskID]) {
    self.viewID = viewID
    self.date = date
    self.taskIDs = taskIDs
  }
}

/// Sets the minutes one view has on a day, in place of the weekday's capacity from the settings; with
/// none clears it.
public struct DayCapacitySet: Equatable, Codable, Sendable {
  public let viewID: ViewID
  public let date: CalendarDate
  /// The capacity of the day before the buffer; `nil` falls back to the weekday's.
  public let minutes: Int?

  public init(viewID: ViewID, date: CalendarDate, minutes: Int?) {
    self.viewID = viewID
    self.date = date
    self.minutes = minutes
  }
}

/// Hands an open task to someone else. It leaves the day it was planned for and stays open: delegating
/// never completes or drops it.
public struct TaskDelegated: Equatable, Codable, Sendable {
  public let taskID: TaskID
  /// Who has the task now; written to the log as `to`.
  public let person: String
  /// The day it was handed over.
  public let since: CalendarDate
  /// The day it comes back to the candidates; `nil` until it is reclaimed.
  public let followUpDate: CalendarDate?

  public init(taskID: TaskID, to person: String, since: CalendarDate, followUpDate: CalendarDate?) {
    self.taskID = taskID
    self.person = person
    self.since = since
    self.followUpDate = followUpDate
  }

  private enum CodingKeys: String, CodingKey {
    case taskID, since, followUpDate
    case person = "to"
  }
}

/// Takes a delegated task back.
public struct TaskReclaimed: Equatable, Codable, Sendable {
  public let taskID: TaskID

  public init(taskID: TaskID) {
    self.taskID = taskID
  }
}

/// Gives up an open task for good: it leaves every list, without being completed.
public struct TaskDropped: Equatable, Codable, Sendable {
  public let taskID: TaskID

  public init(taskID: TaskID) {
    self.taskID = taskID
  }
}
