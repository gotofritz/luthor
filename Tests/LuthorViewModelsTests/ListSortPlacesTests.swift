import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
private func makeLibrary(_ events: [EventEnvelope], show section: NavigationSection) -> LibraryViewModel {
  let log = InMemoryEventLog(events)
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()), view: .default,
    today: { date("2026-10-21") })
  library.reload()
  library.show(section)
  return library
}

/// Three tasks of priority B: "pear" (30m), "Fig" (5m) and "apple" (15m), captured in that order.
private let tasks = [
  captured("t1", "pear", lamport: 1), prioritized("t1", as: .important, lamport: 2),
  estimated("t1", as: 30, lamport: 3),
  captured("t2", "Fig", lamport: 4), prioritized("t2", as: .important, lamport: 5), estimated("t2", as: 5, lamport: 6),
  captured("t3", "apple", lamport: 7), prioritized("t3", as: .important, lamport: 8),
  estimated("t3", as: 15, lamport: 9),
]

@MainActor
@Suite("When the lists of the priorities are sorted by their headers")
struct PriorityListSortTests {
  @Test("each priority's list is sorted on its own")
  func eachListIsSortedApart() {
    let library = makeLibrary(
      tasks + [
        captured("t4", "zebra", lamport: 10), prioritized("t4", as: .critical, lamport: 11),
        captured("t5", "ant", lamport: 12), prioritized("t5", as: .critical, lamport: 13),
      ],
      show: .priorities)
    library.selectPriorities([.critical, .important])

    library.sortBy(.duration, ofList: "priority-B")

    let groups = library.priorityGroups
    #expect(groups.first { $0.priority == .important }?.tasks.map(\.title) == ["Fig", "apple", "pear"])
    #expect(groups.first { $0.priority == .critical }?.tasks.map(\.title) == ["zebra", "ant"])
  }
}

@MainActor
@Suite("When the first cell of a header has a label of its own")
struct FirstCellLabelTests {
  private func steps(_ library: LibraryViewModel, _ listID: String, count: Int) -> [ListSort] {
    (0..<count).map { _ in
      library.sortByFirstCell(ofList: listID)
      return library.sort(ofList: listID)
    }
  }

  @Test("the candidates of Today rest on Suggested, then Title and Created, each both ways, then Suggested again")
  func candidatesCycle() {
    let library = makeLibrary(tasks, show: .today)
    #expect(library.firstCellLabel(ofList: "candidates") == "Suggested")

    let seen = steps(library, "candidates", count: 5)

    #expect(
      seen == [
        ListSort(key: .title, ascending: true), ListSort(key: .title, ascending: false),
        ListSort(key: .created, ascending: true), ListSort(key: .created, ascending: false), .manual,
      ])
    #expect(library.firstCellLabel(ofList: "candidates") == "Suggested")
  }

  @Test("while sorted, the first cell is labelled with the key")
  func labelFollowsTheKey() {
    let library = makeLibrary(tasks, show: .today)
    library.sortByFirstCell(ofList: "candidates")
    #expect(library.firstCellLabel(ofList: "candidates") == "Title")
    library.sortByFirstCell(ofList: "candidates")
    library.sortByFirstCell(ofList: "candidates")
    #expect(library.firstCellLabel(ofList: "candidates") == "Created")
  }

  @Test("a priority's list has only Title, both ways, and then its own order")
  func priorityListCycle() {
    let library = makeLibrary(tasks, show: .priorities)

    let seen = steps(library, "priority-B", count: 3)

    #expect(seen == [ListSort(key: .title, ascending: true), ListSort(key: .title, ascending: false), .manual])
    #expect(library.firstCellLabel(ofList: "priority-B") == "Title")
  }

  @Test("a project's list steps through Title, Created and Due, as before")
  func projectListCycle() {
    let library = makeLibrary(tasks, show: .inbox)

    #expect(steps(library, library.taskListID, count: 7).last == .manual)
    #expect(library.firstCellLabel(ofList: library.taskListID) == "Title")
  }
}

@MainActor
@Suite("When the date column of Prios and Today is sorted")
struct WhenColumnSortTests {
  private static let log = [
    captured("t1", "pear", lamport: 1), prioritized("t1", as: .important, lamport: 2),
    dueSet("t1", on: "2026-10-30", lamport: 3),
    captured("t2", "fig", lamport: 4), prioritized("t2", as: .important, lamport: 5),
    scheduled("t2", on: "2026-10-25", lamport: 6), dueSet("t2", on: "2026-11-20", lamport: 7),
    captured("t3", "apple", lamport: 8), prioritized("t3", as: .important, lamport: 9),
  ]

  @Test("the day a task is scheduled for counts before its due date, and a task with neither comes last")
  func scheduledBeforeDue() {
    let library = makeLibrary(Self.log, show: .priorities)
    library.selectPriorities([.important])

    library.sortBy(.due, ofList: "priority-B")

    #expect(library.priorityGroups.first?.tasks.map(\.title) == ["fig", "pear", "apple"])
  }
}

@MainActor
@Suite("When the candidates of Today are sorted by their header")
struct CandidateSortTests {
  @Test("they start in the suggested order, and the header sorts them by the minutes they count for")
  func startPrioritisedThenSorted() {
    let library = makeLibrary(tasks, show: .today)
    let suggested = library.plan.candidates.map(\.task.title)
    #expect(library.sortedCandidates.map(\.task.title) == suggested)

    library.sortBy(.title, ofList: "candidates")
    #expect(library.sortedCandidates.map(\.task.title) == ["apple", "Fig", "pear"])

    library.sortBy(.title, ofList: "candidates")
    #expect(library.sortedCandidates.map(\.task.title) == ["pear", "Fig", "apple"])
  }

  @Test("the leftovers from earlier days are sorted by the same header")
  func leftoversAreSortedToo() {
    let library = makeLibrary(
      tasks + [scheduled("t1", on: "2026-10-19", lamport: 10), scheduled("t3", on: "2026-10-20", lamport: 11)],
      show: .today)

    library.sortBy(.title, ofList: "candidates")

    #expect(library.sortedCarryOver.map(\.entry.task.title) == ["apple", "pear"])
  }
}

@MainActor
@Suite("When the lists of the daily review are sorted by their headers")
struct DailyReviewSortTests {
  private static let log =
    tasks + [
      scheduled("t1", on: "2026-10-21", lamport: 10), scheduled("t2", on: "2026-10-21", lamport: 11),
      scheduled("t3", on: "2026-10-21", lamport: 12), completed("t1", lamport: 13), completed("t3", lamport: 14),
    ]

  @Test("Done and Not done are sorted apart")
  func doneAndNotDoneApart() {
    let library = makeLibrary(Self.log, show: .review)
    #expect(library.sortedDone.map(\.task.title) == ["pear", "apple"])

    library.sortBy(.title, ofList: "review-done")

    #expect(library.sortedDone.map(\.task.title) == ["apple", "pear"])
    #expect(library.sort(ofList: "review-notdone") == .manual)
    #expect(library.sortedNotDone.map(\.task.title) == ["Fig"])
  }
}

@MainActor
@Suite("When the weekly review is sorted by its headers")
struct WeeklyReviewSortTests {
  private static let log = [
    projectCreated("p1", "Move house", on: "2026-10-12", lamport: 1),
    projectCreated("p2", "Learn Swift", on: "2026-10-10", lamport: 2),
    captured("t1", "pack", under: "p1", lamport: 3), captured("t2", "box", under: "p1", lamport: 4),
  ]

  @Test("the projects due for review are sorted by their title or the day they were created")
  func projectsDueAreSorted() {
    let library = makeLibrary(Self.log, show: .weeklyReview)

    library.sortBy(.title, ofList: "review-projects")
    #expect(library.sortedProjectReview.map(\.project.title) == ["Learn Swift", "Move house"])

    library.sortBy(.title, ofList: "review-projects")
    #expect(library.sortedProjectReview.map(\.project.title) == ["Move house", "Learn Swift"])
  }

  @Test("the tasks of the project picked have a list of their own, apart from the inbox's")
  func taskListsAreApart() {
    let library = makeLibrary(Self.log, show: .weeklyReview)
    library.showReviewProject(TaskID("p1"))

    library.sortBy(.title, ofList: library.taskListID)

    #expect(library.tasks.map(\.title) == ["box", "pack"])
    library.show(.inbox)
    #expect(library.sort(ofList: library.taskListID) == .manual)
  }
}
