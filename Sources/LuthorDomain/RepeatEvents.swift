/// Makes an open task repeat by `rule`, or with none stops it repeating.
public struct TaskRepeatSet: Equatable, Codable, Sendable {
  public let taskID: TaskID
  /// The rule from now on; `nil` stops the repeat.
  public let rule: RepeatRule?

  public init(taskID: TaskID, rule: RepeatRule?) {
    self.taskID = taskID
    self.rule = rule
  }
}

/// Makes `next` a copy of `previous` as it is at that point in the replay, due on `due`: the same title, notes,
/// project, priority, estimate, tags and rule, and the kind of due date it had. Not copied: the day it was planned
/// for, a delegation and the time logged. Ignored when `next` exists already or `previous` does not.
public struct TaskRecurred: Equatable, Codable, Sendable {
  public let previous: TaskID
  public let next: TaskID
  public let due: CalendarDate

  public init(previous: TaskID, next: TaskID, due: CalendarDate) {
    self.previous = previous
    self.next = next
    self.due = due
  }
}
