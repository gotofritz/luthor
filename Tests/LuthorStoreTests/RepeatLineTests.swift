import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a repeat event is written to the log")
struct RepeatLineTests {
  @Test("a TaskRepeatSet is one sorted JSON object with the rule inside")
  func taskRepeatSetIsOneSortedJSONObject() throws {
    let rule = RepeatRule(every: 2, unit: .week, weekdays: [.thursday, .monday])
    let line = try EventLine.encode(repeatSet("t1", rule, id: "e1", lamport: 1))

    #expect(
      line
        == #"{"data":{"rule":{"afterCompletion":false,"every":2,"unit":"week","weekdays":["monday","thursday"]},"taskID":"t1"},"device":"mac","id":"e1","lamport":1,"type":"TaskRepeatSet"}"#
    )
  }

  @Test("a rule without weekdays has no weekdays field, and one counted from completion says so")
  func aRuleWithoutWeekdaysHasNoWeekdaysField() throws {
    let rule = RepeatRule(every: 1, unit: .month, afterCompletion: true)
    let line = try EventLine.encode(repeatSet("t1", rule, id: "e2", lamport: 2))

    #expect(
      line
        == #"{"data":{"rule":{"afterCompletion":true,"every":1,"unit":"month"},"taskID":"t1"},"device":"mac","id":"e2","lamport":2,"type":"TaskRepeatSet"}"#
    )
  }

  @Test("clearing a repeat has no rule field")
  func clearingARepeatHasNoRuleField() throws {
    let line = try EventLine.encode(repeatSet("t1", nil, id: "e3", lamport: 3))

    #expect(line == #"{"data":{"taskID":"t1"},"device":"mac","id":"e3","lamport":3,"type":"TaskRepeatSet"}"#)
  }

  @Test("a TaskRecurred names the task before, the next one and the due day")
  func taskRecurredNamesTheTasksAndTheDueDay() throws {
    let line = try EventLine.encode(recurred("t1", as: "t2", due: "2026-10-26", id: "e4", lamport: 4))

    #expect(
      line
        == #"{"data":{"due":"2026-10-26","next":"t2","previous":"t1"},"device":"mac","id":"e4","lamport":4,"type":"TaskRecurred"}"#
    )
  }

  @Test(
    "each decodes back to the same event",
    arguments: [
      repeatSet("t1", RepeatRule(every: 1, unit: .day)),
      repeatSet("t1", RepeatRule(every: 2, unit: .week, weekdays: [.monday, .thursday])),
      repeatSet("t1", RepeatRule(every: 3, unit: .year, afterCompletion: true)),
      repeatSet("t1", nil),
      recurred("t1", as: "t2", due: "2026-10-26"),
    ])
  func repeatLineDecodesBackToTheSameEvent(event: EventEnvelope) throws {
    #expect(try EventLine.decode(EventLine.encode(event)) == event)
  }
}
