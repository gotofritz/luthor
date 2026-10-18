import LuthorDomain

extension Weekday {
  /// Three letters, as a card lists the days a task repeats on.
  public var abbreviation: String {
    switch self {
    case .monday: "Mon"
    case .tuesday: "Tue"
    case .wednesday: "Wed"
    case .thursday: "Thu"
    case .friday: "Fri"
    case .saturday: "Sat"
    case .sunday: "Sun"
    }
  }
}

extension RepeatRule {
  /// What a card says about the repeat: "Repeats every week on Mon, Thu".
  public var summary: String {
    if afterCompletion { return "Repeats \(every) \(unitName(for: every)) after it is done" }
    var text = "Repeats every " + (every == 1 ? unit.rawValue : "\(every) \(unitName(for: every))")
    if !weekdays.isEmpty {
      text += " on " + Weekday.allCases.filter { weekdays.contains($0) }.map(\.abbreviation).joined(separator: ", ")
    }
    return text
  }

  private func unitName(for count: Int) -> String {
    count == 1 ? unit.rawValue : unit.rawValue + "s"
  }
}
