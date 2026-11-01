import LuthorDomain

/// How far ahead the tasks of a list reach, chosen from the popover of its header. A task counts as dated by the
/// sooner of its due and scheduled dates; a task with neither is never hidden. Like a sort, it is only a way of
/// showing the list and writes nothing to the log.
public enum FutureWindow: String, CaseIterable, Codable, Sendable {
  case all
  case day
  case week
  case month
  case none

  public var label: String {
    switch self {
    case .all: "All"
    case .day: "1 day"
    case .week: "1 week"
    case .month: "1 month"
    case .none: "None"
    }
  }

  /// Whether a task dated `date` is listed: anything up to the end of the window, however far back.
  func includes(dated date: CalendarDate?, today: CalendarDate) -> Bool {
    let days: Int
    switch self {
    case .all: return true
    case .none: days = 0
    case .day: days = 1
    case .week: days = 7
    case .month: days = 30
    }
    guard let date else { return true }
    return date <= today.adding(days: days)
  }
}

extension LibraryViewModel {
  /// How far ahead the place the list is in reaches; all until a header chooses.
  public func futureWindow(ofList listID: String) -> FutureWindow {
    futureWindows[place(ofList: listID)] ?? .all
  }

  /// Narrows the place the list is in to the window.
  public func setFutureWindow(_ window: FutureWindow, ofList listID: String) {
    futureWindows[place(ofList: listID)] = window == .all ? nil : window
    onFutureWindowsChanged?(futureWindows)
    present()
  }

  /// The sooner of the task's due and scheduled dates; `nil` if it has neither.
  func sooner(ofTask id: TaskID) -> CalendarDate? {
    [state.dueDate(of: id)?.date, state.scheduledDate(of: id)].compactMap { $0 }.min()
  }

  /// Whether the open task is listed in the place the list is in.
  func isWithinFuture(_ id: TaskID, inList listID: String, today: CalendarDate) -> Bool {
    let window = futureWindow(ofList: listID)
    return window == .all || window.includes(dated: sooner(ofTask: id), today: today)
  }

  /// The ID of the list of tasks the section shows, which keeps its window.
  var futureListID: String {
    switch section {
    case .priorities: Self.prioritiesListID
    case .today: Self.candidatesListID
    default: taskListID
    }
  }
}
