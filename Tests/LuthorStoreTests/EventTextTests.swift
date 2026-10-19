import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When a log is exported to YAML text")
struct EventTextTests {
  private func golden() throws -> [EventEnvelope] {
    try GoldenLogFixture.lines.map { try #require(EventLine.decodeIfKnown($0)) }
  }

  @Test("the text names its format version")
  func theTextNamesItsFormat() throws {
    let text = try EventText.export([captured("t1", "buy milk")])

    #expect(text.contains("format: 1"))
  }

  @Test("importing the text gives back every event of the golden log")
  func theGoldenLogRoundTrips() throws {
    let events = try golden()

    let sorted = events.sorted(by: EventEnvelope.replayOrder)
    #expect(try EventText.events(from: EventText.export(events)) == sorted)
  }

  @Test("titles that look like other YAML values stay text")
  func awkwardTitlesStayText() throws {
    let titles = ["yes", "null", "2026-10-19", "123", "a: b", "- x", "multi\nline", "  padded  ", "#tag", ""]
    let events = titles.enumerated().map { index, title in
      captured("t\(index)", title, id: "e\(index)", lamport: UInt64(index))
    }

    #expect(try EventText.events(from: EventText.export(events)) == events)
  }

  @Test("an event of an unknown type in the text is skipped")
  func unknownTypesAreSkipped() throws {
    let text = """
      format: 1
      events:
        - data: {taskID: t9}
          device: phone
          id: e9
          lamport: 9
          type: TaskSnoozed
      """

    #expect(try EventText.events(from: text).isEmpty)
  }

  @Test("a newer format version is refused, not guessed at")
  func aNewerFormatIsRefused() {
    #expect(throws: EventLogError.self) { try EventText.events(from: "format: 2\nevents: []\n") }
  }

  @Test("text that is not an export is refused")
  func notAnExportIsRefused() {
    #expect(throws: EventLogError.self) { try EventText.events(from: "just some words") }
    #expect(throws: EventLogError.self) { try EventText.events(from: "format: 1\n") }
  }
}
