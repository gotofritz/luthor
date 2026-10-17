/// A day on the calendar, with no time of day and no time zone: the unit a plan is made in. Plain
/// arithmetic, so the domain needs no calendar from the system; whoever owns the clock hands in today's
/// date. Years 1 to 9999.
public struct CalendarDate: Hashable, Comparable, Sendable {
  public let year: Int
  public let month: Int
  public let day: Int

  /// `nil` unless this is a real day.
  public init?(year: Int, month: Int, day: Int) {
    guard (1...9999).contains(year), (1...12).contains(month),
      (1...Self.daysIn(month: month, of: year)).contains(day)
    else { return nil }
    self.year = year
    self.month = month
    self.day = day
  }

  /// Reads `2026-10-19`; `nil` for anything else, including a day that does not exist.
  public init?(isoString: String) {
    let parts = isoString.split(separator: "-", omittingEmptySubsequences: false)
    let digits: ClosedRange<Character> = "0"..."9"
    guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
      parts.allSatisfy({ part in part.allSatisfy { digits.contains($0) } }),
      let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
    else { return nil }
    self.init(year: year, month: month, day: day)
  }

  /// The day that many days after 1970-01-01, which is a Thursday; negative for days before it.
  public init(daysSinceEpoch days: Int) {
    // Howard Hinnant's civil-from-days, with March as the first month of the year it counts in.
    let shifted = days + 719_468
    let era = shifted / 146_097
    let dayOfEra = shifted - era * 146_097
    let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
    let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
    let monthIndex = (5 * dayOfYear + 2) / 153
    let civilMonth = monthIndex < 10 ? monthIndex + 3 : monthIndex - 9
    year = yearOfEra + era * 400 + (civilMonth <= 2 ? 1 : 0)
    month = civilMonth
    day = dayOfYear - (153 * monthIndex + 2) / 5 + 1
  }

  /// `2026-10-19`.
  public var isoString: String {
    "\(Self.padded(year, width: 4))-\(Self.padded(month, width: 2))-\(Self.padded(day, width: 2))"
  }

  public var weekday: Weekday {
    // 1970-01-01 was a Thursday, the fourth weekday counting from Monday.
    Weekday.allCases[(daysSinceEpoch % 7 + 7 + 3) % 7]
  }

  /// The day this many days later; earlier for a negative number.
  public func adding(days: Int) -> CalendarDate {
    CalendarDate(daysSinceEpoch: daysSinceEpoch + days)
  }

  public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
    (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
  }

  var daysSinceEpoch: Int {
    let shiftedYear = month <= 2 ? year - 1 : year
    let era = shiftedYear / 400
    let yearOfEra = shiftedYear - era * 400
    let dayOfYear = (153 * ((month + 9) % 12) + 2) / 5 + day - 1
    let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
    return era * 146_097 + dayOfEra - 719_468
  }

  private static func daysIn(month: Int, of year: Int) -> Int {
    switch month {
    case 2: isLeap(year) ? 29 : 28
    case 4, 6, 9, 11: 30
    default: 31
    }
  }

  private static func isLeap(_ year: Int) -> Bool {
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  }

  private static func padded(_ number: Int, width: Int) -> String {
    let digits = String(number)
    return String(repeating: "0", count: max(0, width - digits.count)) + digits
  }
}

extension CalendarDate: Codable {
  public init(from decoder: any Decoder) throws {
    let text = try decoder.singleValueContainer().decode(String.self)
    guard let parsed = CalendarDate(isoString: text) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "not a calendar date: \(text)"))
    }
    self = parsed
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(isoString)
  }
}
