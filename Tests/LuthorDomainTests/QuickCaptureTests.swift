import LuthorDomain
import Testing

@Suite("When quick-capture text is parsed")
struct QuickCaptureTests {
  @Test("plain text has no priority and no estimate")
  func plainTextHasNeither() {
    let parsed = QuickCapture.parse("buy milk")

    #expect(parsed == QuickCapture.Parsed(title: "buy milk", priority: nil, estimateMinutes: nil))
  }

  @Test("!a, !b and !c are stripped as Critical, Important and Optional")
  func abcTagsAreStripped() {
    #expect(QuickCapture.parse("call bank !a").priority == .critical)
    #expect(QuickCapture.parse("call bank !b").priority == .important)
    #expect(QuickCapture.parse("call bank !c").priority == .optional)
  }

  @Test("the tag is case-insensitive", arguments: ["!a", "!A"])
  func priorityTagIsCaseInsensitive(tag: String) {
    let parsed = QuickCapture.parse("call bank \(tag)")

    #expect(parsed == QuickCapture.Parsed(title: "call bank", priority: .critical, estimateMinutes: nil))
  }

  @Test("!someday is stripped as the someday priority", arguments: ["!someday", "!SOMEDAY"])
  func somedayTagIsStripped(tag: String) {
    let parsed = QuickCapture.parse("call bank \(tag)")

    #expect(parsed == QuickCapture.Parsed(title: "call bank", priority: .someday, estimateMinutes: nil))
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
