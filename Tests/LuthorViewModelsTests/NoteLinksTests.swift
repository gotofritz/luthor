import Foundation
import LuthorViewModels
import Testing

@Suite("When notes mention web addresses")
struct NoteLinksTests {
  private func found(in notes: String) -> [String] {
    NoteLinks.links(in: notes).map { String(notes[$0.range]) }
  }

  @Test("a full address is a link")
  func fullAddressIsALink() {
    #expect(found(in: "see https://example.com/a?b=1 for details") == ["https://example.com/a?b=1"])
  }

  @Test("an address without a scheme gets http")
  func bareAddressGetsAScheme() {
    let links = NoteLinks.links(in: "try www.example.org")

    #expect(links.map(\.url) == [URL(string: "http://www.example.org")])
  }

  @Test("punctuation after an address is not part of it")
  func trailingPunctuationIsLeftOut() {
    #expect(
      found(in: "read https://example.com/a, then https://example.com/b.") == [
        "https://example.com/a", "https://example.com/b",
      ])
  }

  @Test("notes with no address have no links")
  func plainNotesHaveNoLinks() {
    #expect(NoteLinks.links(in: "oat, not soy").isEmpty)
    #expect(NoteLinks.links(in: "").isEmpty)
  }

  @Test("an email address is not a web link")
  func emailIsNotAWebLink() {
    #expect(NoteLinks.links(in: "write to anna@example.com").isEmpty)
  }

  @Test("brackets and quotes around an address are left out")
  func surroundingBracketsAreLeftOut() {
    #expect(
      found(in: "(see https://example.com/a) and <https://example.com/b> and \"www.example.org\"") == [
        "https://example.com/a", "https://example.com/b", "www.example.org",
      ])
  }

  @Test("a bracket that belongs to the address stays in it")
  func balancedBracketStays() {
    #expect(
      found(in: "https://en.wikipedia.org/wiki/Swift_(language).") == ["https://en.wikipedia.org/wiki/Swift_(language)"]
    )
  }

  @Test("a scheme or www with nothing after it is not a link")
  func emptyAddressIsNotALink() {
    #expect(NoteLinks.links(in: "https:// and www. alone").isEmpty)
  }

  @Test("addresses on several lines are all found, with their places")
  func addressesOnSeveralLines() {
    let notes = "one https://a.example\ntwo\nhttps://b.example"

    #expect(
      NoteLinks.links(in: notes).map { notes.distance(from: notes.startIndex, to: $0.range.lowerBound) } == [4, 26])
  }
}
