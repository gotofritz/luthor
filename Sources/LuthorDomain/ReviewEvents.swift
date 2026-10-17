/// Sets the minutes spent on a task on one day, as the user entered them by hand. Logging again for the same
/// task and day replaces the minutes; none (or zero) clears them.
public struct TaskTimeLogged: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let date: CalendarDate
  /// The minutes the task took on that day; `nil` clears them.
  public let minutes: Int?

  public init(taskID: TaskID, date: CalendarDate, minutes: Int?) {
    self.taskID = taskID
    self.date = date
    self.minutes = minutes
  }
}

/// Sets the minutes one view spent on one day on work that was not in the plan. Logging again for the same
/// view and day replaces the minutes; none (or zero) clears them.
public struct UnplannedTimeLogged: Equatable, Codable, Sendable {
  public let viewID: ViewID
  public let date: CalendarDate
  /// The unplanned minutes of the day; `nil` clears them.
  public let minutes: Int?

  public init(viewID: ViewID, date: CalendarDate, minutes: Int?) {
    self.viewID = viewID
    self.date = date
    self.minutes = minutes
  }
}

/// Closes the review of one view's day, with a one-line note. Reviewing the day again replaces the note.
public struct DayReviewed: Equatable, Codable, Sendable {
  public let viewID: ViewID
  public let date: CalendarDate
  /// What the day taught, in one line; long reflection belongs in a notes app. `nil` for none.
  public let note: String?

  public init(viewID: ViewID, date: CalendarDate, note: String?) {
    self.viewID = viewID
    self.date = date
    self.note = note
  }
}
