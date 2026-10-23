/// How a task repeats: every so many days, weeks, months or years. A rule never ends.
public struct RepeatRule: Equatable, Hashable, Sendable {
  public enum Unit: String, Codable, Sendable, CaseIterable {
    case day, week, month, year
  }

  /// How many units apart the occurrences are; at least one.
  public let every: Int
  public let unit: Unit
  /// The days of the week a weekly rule falls on; none means the weekday of the due date. Only a weekly rule
  /// counted from the due date has weekdays.
  public let weekdays: Set<Weekday>
  /// Whether the next due date is counted from the day the task is done, not from the previous due date.
  public let afterCompletion: Bool

  public init(every: Int, unit: Unit, weekdays: Set<Weekday> = [], afterCompletion: Bool = false) {
    self.every = max(1, every)
    self.unit = unit
    self.weekdays = unit == .week && !afterCompletion ? weekdays : []
    self.afterCompletion = afterCompletion
  }

  /// This rule counted from the day the task is done, as a task with no due date has to be.
  public var countingFromCompletion: RepeatRule {
    RepeatRule(every: every, unit: unit, afterCompletion: true)
  }

  /// The due date of the next occurrence. Counted from completion, it is `completedOn` plus the interval.
  /// Otherwise it is the first date of the rule after the previous due date and after `today`, so a task done
  /// late does not leave a pile of missed occurrences behind. A month keeps the day number of the previous due
  /// date, and falls on the last day of a shorter month.
  public func nextDue(after previousDue: CalendarDate, completedOn: CalendarDate, today: CalendarDate)
    -> CalendarDate
  {
    if afterCompletion { return advance(completedOn, by: every) }
    let floor = max(previousDue, today)
    if !weekdays.isEmpty { return nextWeekday(after: previousDue, floor: floor) }
    switch unit {
    case .day, .week:
      let span = every * (unit == .week ? 7 : 1)
      let steps = (floor.daysSinceEpoch - previousDue.daysSinceEpoch) / span + 1
      return previousDue.adding(days: steps * span)
    case .month, .year:
      var steps = 1
      var candidate = advance(previousDue, by: every)
      while candidate <= floor && steps < Self.stepLimit {
        steps += 1
        candidate = advance(previousDue, by: steps * every)
      }
      return candidate
    }
  }

  /// A guard against a rule that cannot get past `today`, which only a date at the end of the calendar causes.
  private static let stepLimit = 12_000

  private func advance(_ day: CalendarDate, by count: Int) -> CalendarDate {
    switch unit {
    case .day: day.adding(days: count)
    case .week: day.adding(days: 7 * count)
    case .month: day.adding(months: count)
    case .year: day.adding(years: count)
    }
  }

  /// The first chosen weekday after `floor`, in a week that is a multiple of `every` weeks from the one the
  /// previous due date is in.
  private func nextWeekday(after previousDue: CalendarDate, floor: CalendarDate) -> CalendarDate {
    let anchor = Self.weekStart(of: previousDue)
    var day = floor.adding(days: 1)
    for _ in 0..<(7 * every + 7) {
      let weeksApart = (Self.weekStart(of: day) - anchor) / 7
      if weekdays.contains(day.weekday) && weeksApart % every == 0 { return day }
      day = day.adding(days: 1)
    }
    return day
  }

  /// The Monday of the week the day is in, as days since the epoch.
  private static func weekStart(of day: CalendarDate) -> Int {
    day.daysSinceEpoch - (Weekday.allCases.firstIndex(of: day.weekday) ?? 0)
  }
}

extension RepeatRule: Codable {
  private enum CodingKeys: String, CodingKey {
    case every, unit, weekdays, afterCompletion
  }

  /// A rule written without weekdays or without the mode is counted from the due date, on its weekday.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      every: try container.decode(Int.self, forKey: .every),
      unit: try container.decode(Unit.self, forKey: .unit),
      weekdays: Set(try container.decodeIfPresent([Weekday].self, forKey: .weekdays) ?? []),
      afterCompletion: try container.decodeIfPresent(Bool.self, forKey: .afterCompletion) ?? false)
  }

  /// The weekdays go in the order of the week, and are left out when there are none.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(every, forKey: .every)
    try container.encode(unit, forKey: .unit)
    try container.encode(afterCompletion, forKey: .afterCompletion)
    if !weekdays.isEmpty {
      try container.encode(Weekday.allCases.filter { weekdays.contains($0) }, forKey: .weekdays)
    }
  }
}
