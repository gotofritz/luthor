import Foundation
import LuthorDomain
import LuthorTestSupport
import Testing

private func every(
  _ count: Int, _ unit: RepeatRule.Unit, on weekdays: Set<Weekday> = [], afterCompletion: Bool = false
) -> RepeatRule {
  RepeatRule(every: count, unit: unit, weekdays: weekdays, afterCompletion: afterCompletion)
}

@Suite("When a repeat rule is made")
struct RepeatRuleShapeTests {
  @Test("a count below one becomes one")
  func aCountBelowOneBecomesOne() {
    #expect(every(0, .day).every == 1)
    #expect(every(-3, .week).every == 1)
  }

  @Test("weekdays are kept only for a weekly rule counted from the due date")
  func weekdaysAreKeptOnlyForAFixedWeeklyRule() {
    #expect(every(1, .week, on: [.monday, .thursday]).weekdays == [.monday, .thursday])
    #expect(every(1, .month, on: [.monday]).weekdays.isEmpty)
    #expect(every(1, .week, on: [.monday], afterCompletion: true).weekdays.isEmpty)
  }

  @Test("it encodes with its weekdays in the order of the week, and decodes back")
  func itEncodesAndDecodesBack() throws {
    let rule = every(2, .week, on: [.thursday, .monday])
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let json = try encoder.encode(rule)

    #expect(
      String(bytes: json, encoding: .utf8)
        == #"{"afterCompletion":false,"every":2,"unit":"week","weekdays":["monday","thursday"]}"#
    )
    #expect(try JSONDecoder().decode(RepeatRule.self, from: json) == rule)
  }

  @Test("a rule written without weekdays or the mode reads as fixed with none")
  func aRuleWithoutOptionalFieldsReadsAsFixed() throws {
    let rule = try JSONDecoder().decode(RepeatRule.self, from: Data(#"{"every":3,"unit":"day"}"#.utf8))

    #expect(rule == every(3, .day))
  }
}

@Suite("When the next due date of a rule counted from the due date is worked out")
struct FixedRepeatTests {
  @Test(
    "it is the first date of the rule after the previous due date and after today",
    arguments: [
      // days
      (every(1, .day), "2026-10-19", "2026-10-19", "2026-10-20"),
      (every(3, .day), "2026-10-19", "2026-10-19", "2026-10-22"),
      (every(1, .day), "2026-10-19", "2026-10-23", "2026-10-24"),
      (every(2, .day), "2026-10-19", "2026-10-24", "2026-10-25"),
      (every(1, .day), "2026-10-19", "2026-10-10", "2026-10-20"),
      // weeks, without weekdays
      (every(1, .week), "2026-10-19", "2026-10-19", "2026-10-26"),
      (every(2, .week), "2026-10-19", "2026-10-19", "2026-11-02"),
      (every(1, .week), "2026-10-05", "2026-10-23", "2026-10-26"),
      // months keep the day number, a 31st falls on the last day of a shorter month
      (every(1, .month), "2026-01-15", "2026-01-15", "2026-02-15"),
      (every(1, .month), "2026-01-31", "2026-01-31", "2026-02-28"),
      (every(1, .month), "2028-01-31", "2028-01-31", "2028-02-29"),
      (every(1, .month), "2026-03-31", "2026-03-31", "2026-04-30"),
      (every(1, .month), "2026-12-15", "2026-12-15", "2027-01-15"),
      (every(3, .month), "2026-11-30", "2026-11-30", "2027-02-28"),
      (every(1, .month), "2026-08-31", "2026-10-19", "2026-10-31"),
      // years
      (every(1, .year), "2026-10-19", "2026-10-19", "2027-10-19"),
      (every(2, .year), "2026-10-19", "2026-10-19", "2028-10-19"),
      (every(1, .year), "2028-02-29", "2028-02-29", "2029-02-28"),
    ])
  func nextDate(rule: RepeatRule, previous: String, today: String, expected: String) {
    #expect(rule.nextDue(after: date(previous), completedOn: date(today), today: date(today)) == date(expected))
  }
}

private let mondayAndThursday = every(1, .week, on: [.monday, .thursday])

@Suite("When the next due date of a weekly rule on weekdays is worked out")
struct WeekdayRepeatTests {
  @Test(
    "it is the next chosen weekday after the previous due date and after today",
    arguments: [
      (mondayAndThursday, "2026-10-19", "2026-10-19", "2026-10-22"),
      (mondayAndThursday, "2026-10-22", "2026-10-22", "2026-10-26"),
      (mondayAndThursday, "2026-10-19", "2026-10-21", "2026-10-22"),
      (mondayAndThursday, "2026-10-19", "2026-10-23", "2026-10-26"),
      (mondayAndThursday, "2026-10-21", "2026-10-21", "2026-10-22"),
      (mondayAndThursday, "2026-10-19", "2026-10-12", "2026-10-22"),
      (every(1, .week, on: [.sunday, .monday]), "2026-10-25", "2026-10-25", "2026-10-26"),
      (every(1, .week, on: [.friday]), "2026-10-19", "2026-10-19", "2026-10-23"),
      // every second week counts weeks from the one the previous due date is in
      (every(2, .week, on: [.monday, .thursday]), "2026-10-19", "2026-10-19", "2026-10-22"),
      (every(2, .week, on: [.monday, .thursday]), "2026-10-22", "2026-10-22", "2026-11-02"),
    ])
  func nextWeekday(rule: RepeatRule, previous: String, today: String, expected: String) {
    #expect(rule.nextDue(after: date(previous), completedOn: date(today), today: date(today)) == date(expected))
  }
}

@Suite("When the next due date of a rule counted from completion is worked out")
struct AfterCompletionRepeatTests {
  @Test(
    "it is the completion day plus the interval, whatever the previous due date was",
    arguments: [
      (every(1, .day, afterCompletion: true), "2026-10-19", "2026-10-23", "2026-10-24"),
      (every(3, .day, afterCompletion: true), "2026-10-19", "2026-10-19", "2026-10-22"),
      (every(1, .week, afterCompletion: true), "2026-10-19", "2026-10-23", "2026-10-30"),
      (every(1, .week, on: [.monday], afterCompletion: true), "2026-10-19", "2026-10-23", "2026-10-30"),
      (every(1, .month, afterCompletion: true), "2026-10-01", "2026-01-31", "2026-02-28"),
      (every(1, .year, afterCompletion: true), "2028-01-01", "2028-02-29", "2029-02-28"),
    ])
  func nextDate(rule: RepeatRule, previous: String, completed: String, expected: String) {
    #expect(
      rule.nextDue(after: date(previous), completedOn: date(completed), today: date(completed)) == date(expected))
  }
}
