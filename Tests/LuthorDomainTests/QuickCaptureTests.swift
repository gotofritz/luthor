import LuthorDomain
import Testing

@Suite("When quick-capture text is parsed")
struct QuickCaptureTests {
  @Test("plain text has no priority and no estimate")
  func plainTextHasNeither() {
    let parsed = QuickCapture.parse("buy milk")

    #expect(parsed == QuickCapture.Parsed(title: "buy milk", priority: nil, estimateMinutes: nil))
  }

  @Test("a priority tag is stripped from the title", arguments: [
    ("call bank !a", Priority.critical),
    ("call bank !A", Priority.critical),
    ("call bank !b", Priority.important),
    ("call bank !c", Priority.optional),
    ("call bank !someday", Priority.someday),
    ("call bank !SOMEDAY", Priority.someday),
  ])
  func priorityTagIsStripped(input: String, priority: Priority) {
    let parsed = QuickCapture.parse(input)

    #expect(parsed == QuickCapture.Parsed(title: "call bank", priority: priority, estimateMinutes: nil))
  }

  @Test("an estimate tag is stripped from the title")
  func estimateTagIsStripped() {
    let parsed = QuickCapture.parse("call bank 15m")

    #expect(parsed == QuickCapture.Parsed(title: "call bank", priority: nil, estimateMinutes: 15))
  }

  @Test("a priority and an estimate tag together are both stripped, in any order")
  func bothTagsAreStripped() {
    #expect(
      QuickCapture.parse("call bank !a 15m")
        == QuickCapture.Parsed(title: "call bank", priority: .critical, estimateMinutes: 15))
    #expect(
      QuickCapture.parse("15m call bank !a")
        == QuickCapture.Parsed(title: "call bank", priority: .critical, estimateMinutes: 15))
  }

  @Test("a tag in the middle of the title still comes out")
  func tagInTheMiddleIsStripped() {
    let parsed = QuickCapture.parse("call !a the bank")

    #expect(parsed == QuickCapture.Parsed(title: "call the bank", priority: .critical, estimateMinutes: nil))
  }

  @Test("the last of a repeated tag wins")
  func lastTagWins() {
    let parsed = QuickCapture.parse("call bank !a !c 15m 30m")

    #expect(parsed == QuickCapture.Parsed(title: "call bank", priority: .optional, estimateMinutes: 30))
  }

  @Test("an unknown ! tag is left in the title")
  func unknownBangTagIsLeftAlone() {
    let parsed = QuickCapture.parse("call bank !urgent")

    #expect(parsed == QuickCapture.Parsed(title: "call bank !urgent", priority: nil, estimateMinutes: nil))
  }

  @Test("zero or negative minutes are left in the title", arguments: ["0m", "-5m"])
  func nonPositiveMinutesAreLeftAlone(token: String) {
    let parsed = QuickCapture.parse("call bank \(token)")

    #expect(parsed.estimateMinutes == nil)
    #expect(parsed.title == "call bank \(token)")
  }

  @Test("surrounding whitespace collapses with the tags")
  func surroundingWhitespaceCollapses() {
    let parsed = QuickCapture.parse("  call bank   !a  ")

    #expect(parsed == QuickCapture.Parsed(title: "call bank", priority: .critical, estimateMinutes: nil))
  }
}
