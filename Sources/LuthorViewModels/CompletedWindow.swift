import LuthorDomain

/// How far back the completed tasks and projects of a list reach, chosen from the popover of its header. Like a
/// sort, it is only a way of showing the list and writes nothing to the log.
public enum CompletedWindow: String, CaseIterable, Codable, Sendable {
  case all
  case pastDay
  case past3Days
  case pastWeek
  case none

  public var label: String {
    switch self {
    case .all: "All"
    case .pastDay: "Past day"
    case .past3Days: "Past 3 days"
    case .pastWeek: "Past week"
    case .none: "None"
    }
  }

  /// Whether an item completed on `day` is listed. A dropped item, and a completion from before the day was
  /// kept, have no day: only `all` lists them.
  func includes(completedOn day: CalendarDate?, today: CalendarDate) -> Bool {
    let days: Int
    switch self {
    case .all: return true
    case .none: return false
    case .pastDay: days = 1
    case .past3Days: days = 3
    case .pastWeek: days = 7
    }
    guard let day else { return false }
    return day >= today.adding(days: -days)
  }
}
