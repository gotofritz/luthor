import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("When a column of the browser is resized from its edge")
struct ColumnWidthsTests {
  @Test("in the priorities place the priority column and the list keep separate widths")
  func prioritiesPlaceColumnsAreSeparate() {
    let (library, _) = makeInbox()

    library.setColumnWidth(600, of: LibraryViewModel.prioritiesListID)

    #expect(LibraryViewModel.priorityPickerColumnID != LibraryViewModel.prioritiesListID)
    #expect(library.columnWidth(of: LibraryViewModel.priorityPickerColumnID, usually: 200) == 200)
  }

  @Test("a column has its usual width until it is resized")
  func usualWidth() {
    let (library, _) = makeInbox()

    #expect(library.columnWidth(of: "top", usually: 192) == 192)
  }

  @Test("each column keeps the width it was dragged to, and no other changes")
  func widthBelongsToAColumn() {
    let (library, _) = makeInbox()

    library.setColumnWidth(260, of: "top")

    #expect(library.columnWidth(of: "top", usually: 192) == 260)
    #expect(library.columnWidth(of: "project-p1", usually: 440) == 440)
  }

  @Test("a width is held between a sliver and a screen")
  func widthIsClamped() {
    let (library, _) = makeInbox()

    library.setColumnWidth(2, of: "top")
    #expect(library.columnWidth(of: "top", usually: 192) == LibraryViewModel.columnWidthRange.lowerBound)

    library.setColumnWidth(5000, of: "top")
    #expect(library.columnWidth(of: "top", usually: 192) == LibraryViewModel.columnWidthRange.upperBound)
  }

  @Test("resetting a column gives it its usual width back")
  func resetting() {
    let (library, _) = makeInbox()
    library.setColumnWidth(260, of: "top")

    library.resetColumnWidth(of: "top")

    #expect(library.columnWidth(of: "top", usually: 192) == 192)
  }

  @Test("each change is handed on to be kept, and widths kept before are the ones it starts with")
  func widthsAreKept() {
    let (library, _) = makeInbox()
    var kept: [String: Double] = [:]
    library.onColumnWidthsChanged = { kept = $0 }

    library.setColumnWidth(300, of: "project-p1")

    #expect(kept == ["project-p1": 300])
    let restored = LibraryViewModel(
      log: InMemoryEventLog([]), commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
      today: { date("2026-10-19") }, columnWidths: kept)
    #expect(restored.columnWidth(of: "project-p1", usually: 440) == 300)
  }

  @Test("the widest title of a project's column is the longest of its tasks and sub-projects")
  func widestTitleOfAColumn() {
    let (library, _) = makeInbox([
      projectCreated("p1", "Garden", lamport: 1),
      captured("t1", "mow", under: "p1", lamport: 2),
      projectCreated("p2", "Roses and other flowers", under: "p1", lamport: 3),
    ])
    library.open(.project(TaskID("p1")))

    #expect(library.widestTitle(inColumn: "project-p1") == "Roses and other flowers")
    #expect(library.widestTitle(inColumn: "top") == "Garden")
  }

  @Test("the widest title of the inbox is the longest of its tasks")
  func widestTitleOfTheInbox() {
    let (library, _) = makeInbox([captured("t1", "buy milk", lamport: 1), captured("t2", "call", lamport: 2)])

    #expect(library.widestTitle(inColumn: library.taskListID) == "buy milk")
  }

  @Test("fitting a list adds the cells its rows show to the width of its title")
  func fittedWidth() {
    let (library, _) = makeInbox()
    let withEverything = library.fittedWidth(forTitleWidth: 100, inList: library.taskListID)

    library.toggleColumn(.duration, inList: library.taskListID)

    #expect(withEverything - library.fittedWidth(forTitleWidth: 100, inList: library.taskListID) == 32)
    #expect(library.fittedWidth(forTitleWidth: 150, inList: library.taskListID) > withEverything - 32)
  }
}
