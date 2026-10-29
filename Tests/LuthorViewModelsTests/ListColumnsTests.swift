import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
private func makeLibrary() -> LibraryViewModel {
  let library = LibraryViewModel(
    log: InMemoryEventLog([]), commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
    view: .default, today: { date("2026-10-21") })
  library.reload()
  return library
}

@MainActor
@Suite("When the columns of a list are turned on and off from its header")
struct ListColumnsTests {
  @Test("every column is shown to begin with, but the date, which only Prios and Today show")
  func defaults() {
    let library = makeLibrary()

    #expect(ListColumn.allCases.allSatisfy { library.isColumnShown($0, inList: LibraryViewModel.prioritiesListID) })
    #expect(library.isColumnShown(.duration, inList: "project-p1"))
    #expect(!library.isColumnShown(.when, inList: "project-p1"))
  }

  @Test("the lists of one place share their columns, and each place has its own")
  func placesAreIndependent() {
    let library = makeLibrary()

    library.toggleColumn(.duration, inList: "project-p1")

    #expect(!library.isColumnShown(.duration, inList: "project-p1"))
    #expect(!library.isColumnShown(.duration, inList: "project-p2"))
    #expect(!library.isColumnShown(.duration, inList: "top"))
    #expect(library.isColumnShown(.duration, inList: LibraryViewModel.prioritiesListID))
    #expect(library.isColumnShown(.duration, inList: library.taskListID))
    #expect(library.isColumnShown(.priority, inList: "project-p1"))

    library.toggleColumn(.duration, inList: "top")

    #expect(library.isColumnShown(.duration, inList: "project-p1"))
  }

  @Test("the columns a list was left with are the ones it starts with")
  func startsWithTheKeptColumns() {
    let library = LibraryViewModel(
      log: InMemoryEventLog([]), commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
      today: { date("2026-10-21") }, listColumns: ["projects": [.priority, .when]])

    #expect(!library.isColumnShown(.duration, inList: "project-p1"))
    #expect(library.isColumnShown(.when, inList: "project-p1"))
    #expect(!library.isColumnShown(.duration, inList: "project-p2"))
    #expect(library.isColumnShown(.duration, inList: LibraryViewModel.prioritiesListID))
  }

  @Test("each change is handed on to be kept, with every list's columns")
  func changesAreHandedOn() {
    let library = makeLibrary()
    var kept: [String: Set<ListColumn>] = [:]
    library.onListColumnsChanged = { kept = $0 }

    library.toggleColumn(.duration, inList: "project-p1")

    #expect(kept["projects"] == [.status, .priority])
  }

  @Test("the date can be turned on in a list of a project, and then it is the date column")
  func dateOnInAProject() {
    let library = makeLibrary()

    library.toggleColumn(.when, inList: "project-p1")

    #expect(library.showsWhenColumn(ofList: "project-p1"))
    #expect(library.showsWhenColumn(ofList: "project-p2"))
    #expect(!library.showsWhenColumn(ofList: library.taskListID))
  }

  @Test("a list with a date column leaves Due out of its first cell, which steps through Title and Created")
  func firstCellOfAProjectList() {
    let library = makeLibrary()
    var seen: [ListSort] = []
    library.toggleColumn(.when, inList: "project-p1")

    for _ in 0..<5 {
      library.sortByFirstCell(ofList: "project-p1")
      seen.append(library.sort(ofList: "project-p1"))
    }

    #expect(
      seen == [
        ListSort(key: .title, ascending: true), ListSort(key: .title, ascending: false),
        ListSort(key: .created, ascending: true), ListSort(key: .created, ascending: false), .manual,
      ])
  }
}
