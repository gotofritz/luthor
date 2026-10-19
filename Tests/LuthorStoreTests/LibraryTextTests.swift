import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@Suite("When the tasks and projects are written as YAML text")
struct LibraryTextTests {
  private func goldenExport() throws -> LibraryExport {
    let events = try GoldenLogFixture.lines.map { try #require(EventLine.decodeIfKnown($0)) }
    return LibraryState.replay(events).export()
  }

  @Test("the text names its format version")
  func theTextNamesItsFormat() throws {
    #expect(try LibraryText.export(goldenExport()).contains("format: 1"))
  }

  @Test("reading the text gives back what was written")
  func theTextRoundTrips() throws {
    let export = try goldenExport()

    #expect(try LibraryText.library(from: LibraryText.export(export)) == export)
  }

  @Test("importing the text into an empty library gives the same tasks and projects")
  func importingGivesTheSameLibrary() throws {
    let export = try goldenExport()
    let text = try LibraryText.export(export)
    let commands = Commands(deviceID: DeviceID("other"), ids: SequentialIDs())

    let events = try commands.importLibrary(LibraryText.library(from: text), log: [])

    #expect(LibraryState.replay(events).export() == export)
  }

  @Test("titles that look like other YAML values stay text")
  func awkwardTitlesStayText() throws {
    let titles = ["yes", "null", "2026-10-19", "123", "a: b", "- x", "multi\nline", "  padded  ", "#tag"]
    let items = titles.enumerated().map { index, title in
      ExportedItem(id: TaskID("t\(index)"), title: title, view: .default, notes: title)
    }
    let export = LibraryExport(views: [], tags: [], items: items)

    #expect(try LibraryText.library(from: LibraryText.export(export)) == export)
  }

  @Test("a newer format version is refused, not guessed at")
  func aNewerFormatIsRefused() {
    #expect(throws: EventLogError.self) {
      try LibraryText.library(from: "format: 2\nviews: []\ntags: []\nitems: []\n")
    }
  }

  @Test("text that is not an export is refused")
  func notAnExportIsRefused() {
    #expect(throws: EventLogError.self) { try LibraryText.library(from: "just some words") }
  }
}
