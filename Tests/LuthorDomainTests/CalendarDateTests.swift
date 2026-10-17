import Foundation
import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When a calendar date is written as text")
struct CalendarDateTextTests {
  @Test("a real day reads back as the same day")
  func aRealDayReadsBack() {
    let parsed = CalendarDate(isoString: "2026-10-19")

    #expect(parsed == CalendarDate(year: 2026, month: 10, day: 19))
    #expect(parsed?.isoString == "2026-10-19")
  }

  @Test("a leap day exists only in a leap year")
  func aLeapDayExistsOnlyInALeapYear() {
    #expect(CalendarDate(isoString: "2028-02-29") != nil)
    #expect(CalendarDate(isoString: "2100-02-29") == nil)
    #expect(CalendarDate(isoString: "2026-02-29") == nil)
  }

  @Test(
    "text that is not a day is refused",
    arguments: ["", "2026-13-01", "2026-00-10", "2026-04-31", "2026-4-1", "20261019", "tomorrow", "2026-10-19x"])
  func textThatIsNotADayIsRefused(text: String) {
    #expect(CalendarDate(isoString: text) == nil)
  }

  @Test("a date encodes as one JSON string and decodes back")
  func aDateEncodesAsOneJSONString() throws {
    let encoded = try JSONEncoder().encode([date("2026-10-19")])

    #expect(String(bytes: encoded, encoding: .utf8) == #"["2026-10-19"]"#)
    #expect(try JSONDecoder().decode([CalendarDate].self, from: encoded) == [date("2026-10-19")])
  }

  @Test("decoding a string that is not a day fails")
  func decodingAStringThatIsNotADayFails() {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode([CalendarDate].self, from: Data(#"["2026-02-30"]"#.utf8))
    }
  }
}

@Suite("When days are counted")
struct CalendarDateArithmeticTests {
  @Test(
    "adding days crosses months, years and leap days",
    arguments: [
      ("2026-10-19", 1, "2026-10-20"),
      ("2026-10-31", 1, "2026-11-01"),
      ("2026-12-31", 1, "2027-01-01"),
      ("2028-02-28", 1, "2028-02-29"),
      ("2028-02-29", 1, "2028-03-01"),
      ("2026-03-01", -1, "2026-02-28"),
      ("2026-10-19", 0, "2026-10-19"),
      ("2026-10-19", 365, "2027-10-19"),
    ])
  func addingDaysCrossesMonthsYearsAndLeapDays(start: String, days: Int, expected: String) {
    #expect(date(start).adding(days: days) == date(expected))
  }

  @Test(
    "each date has its weekday",
    arguments: [
      ("1970-01-01", Weekday.thursday),
      ("2026-10-17", .saturday),
      ("2026-10-18", .sunday),
      ("2026-10-19", .monday),
      ("2026-10-23", .friday),
      ("2028-02-29", .tuesday),
    ])
  func eachDateHasItsWeekday(day: String, weekday: Weekday) {
    #expect(date(day).weekday == weekday)
  }

  @Test("dates order by day")
  func datesOrderByDay() {
    #expect(date("2026-10-19") < date("2026-10-20"))
    #expect(date("2026-09-30") < date("2026-10-01"))
    #expect(date("2025-12-31") < date("2026-01-01"))
    #expect(!(date("2026-10-19") < date("2026-10-19")))
  }
}
