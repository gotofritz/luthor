import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("When a column of a list is resized from its header")
struct ColumnWidthsTests {
  @Test("a column has its usual width until it is resized")
  func defaultWidths() {
    let (library, _) = makeInbox()

    #expect(library.columnWidth(.duration, inList: "project-p1") == 28)
    #expect(library.columnWidth(.when, inList: library.taskListID) == 70)
  }

  @Test("the width is kept for the place the list is in, and for no other")
  func widthBelongsToAPlace() {
    let (library, _) = makeInbox()

    library.setColumnWidth(50, of: .duration, inList: "project-p1")

    #expect(library.columnWidth(.duration, inList: "project-p2") == 50)
    #expect(library.columnWidth(.duration, inList: "top") == 50)
    #expect(library.columnWidth(.priority, inList: "project-p1") == 28)
    #expect(library.columnWidth(.duration, inList: LibraryViewModel.prioritiesListID) == 28)
  }

  @Test("a width is held between a hand's breadth and a screen")
  func widthIsClamped() {
    let (library, _) = makeInbox()

    library.setColumnWidth(2, of: .priority, inList: "top")
    #expect(library.columnWidth(.priority, inList: "top") == LibraryViewModel.columnWidthRange.lowerBound)

    library.setColumnWidth(5000, of: .priority, inList: "top")
    #expect(library.columnWidth(.priority, inList: "top") == LibraryViewModel.columnWidthRange.upperBound)
  }

  @Test("each change is handed on to be kept, and widths kept before are the ones it starts with")
  func widthsAreKept() {
    let (library, _) = makeInbox()
    var kept: [String: [String: Double]] = [:]
    library.onColumnWidthsChanged = { kept = $0 }

    library.setColumnWidth(44, of: .when, inList: "project-p1")

    #expect(kept == ["projects": ["when": 44]])
    let restored = LibraryViewModel(
      log: InMemoryEventLog([]), commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
      today: { date("2026-10-19") }, columnWidths: kept)
    #expect(restored.columnWidth(.when, inList: "top") == 44)
  }

  @Test("the widest text of the duration column is the longest estimate listed")
  func widestDuration() {
    let (library, _) = makeInbox([
      projectCreated("p1", "Garden", lamport: 1),
      captured("t1", "a", under: "p1", lamport: 2), estimated("t1", as: 5, lamport: 3),
      captured("t2", "b", under: "p1", lamport: 4), estimated("t2", as: 120, lamport: 5),
    ])
    library.open(.project(TaskID("p1")))

    #expect(library.widestText(in: .duration, inList: "project-p1") == "120m")
  }

  @Test("a column with nothing to show has no widest text")
  func widestTextOfAnEmptyColumn() {
    let (library, _) = makeInbox([captured("t1", "a", lamport: 1)])

    #expect(library.widestText(in: .duration, inList: library.taskListID) == nil)
    #expect(library.widestText(in: .priority, inList: library.taskListID) == nil)
  }
}
