/// How often a project is reviewed: every so many days, or never. On the wire it is the number of days, with
/// 0 for off.
public enum ReviewInterval: Hashable, Sendable {
  case off
  case every(days: Int)

  /// The weekly review every project has until told otherwise.
  public static let weekly = ReviewInterval.every(days: 7)

  /// Every `days` days; no days, or fewer, is off.
  public init(days: Int?) {
    if let days, days > 0 {
      self = .every(days: days)
    } else {
      self = .off
    }
  }

  /// The days between reviews; `nil` when review is off.
  public var days: Int? {
    switch self {
    case .off: nil
    case .every(let days): days > 0 ? days : nil
    }
  }
}

extension ReviewInterval: Codable {
  public init(from decoder: any Decoder) throws {
    self.init(days: try decoder.singleValueContainer().decode(Int.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(days ?? 0)
  }
}

/// Sets how often projects are reviewed unless a project has an interval of its own. Turning review off for
/// every project is setting it to off.
public struct ReviewDefaultSet: Equatable, Codable, Sendable {
  public let interval: ReviewInterval

  public init(interval: ReviewInterval) {
    self.interval = interval
  }
}

/// Sets how often one project is reviewed, in place of the default; with none clears it, so the default
/// applies again.
public struct ReviewIntervalSet: Equatable, Codable, Sendable {
  public let taskID: TaskID
  /// The project's own interval from now on, which may be off; `nil` clears it.
  public let interval: ReviewInterval?

  public init(taskID: TaskID, interval: ReviewInterval?) {
    self.taskID = taskID
    self.interval = interval
  }
}

/// Sets the day a project is reviewed next, in place of one interval after it was last reviewed, so that
/// projects made together can be spread over the weeks. Reviewing the project drops it, and the next review
/// counts from the day reviewed again.
public struct ReviewDateSet: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let date: CalendarDate

  public init(taskID: TaskID, date: CalendarDate) {
    self.taskID = taskID
    self.date = date
  }
}

/// Marks an open project reviewed on a day. Its next review falls one interval after that day.
public struct TaskReviewed: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let date: CalendarDate

  public init(taskID: TaskID, date: CalendarDate) {
    self.taskID = taskID
    self.date = date
  }
}
