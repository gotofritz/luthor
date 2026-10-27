import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
private func makeLibrary() -> LibraryViewModel {
  let log = InMemoryEventLog([
    captured("t1", "write report", lamport: 1), scheduled("t1", on: "2026-10-19", lamport: 2),
    tagCreated("home", "home", lamport: 3), tagged("t1", with: "home", lamport: 4),
  ])
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
    today: { date("2026-10-19") })
  library.reload()
  return library
}

@MainActor
@Suite("When a place other than Today, the calendar or the tags is shown")
struct LazyPresentViewModelTests {
  @Test("the plan, the calendar and the tag counts are not worked out")
  func otherPlacesAreNotWorkedOut() {
    let library = makeLibrary()

    #expect(library.plan.entries.isEmpty)
    #expect(library.calendarDays.isEmpty)
    #expect(library.tagTaskCounts.isEmpty)
  }

  @Test("going to Today works out the plan")
  func todayWorksOutThePlan() {
    let library = makeLibrary()

    library.show(.today)

    #expect(library.plan.entries.map(\.task.id) == [TaskID("t1")])
  }

  @Test("going to the calendar works out its days")
  func calendarWorksOutItsDays() {
    let library = makeLibrary()

    library.show(.calendar)

    #expect(!library.calendarDays.isEmpty)
  }

  @Test("going to the tags works out how many tasks each carries")
  func tagsWorkOutTheirCounts() {
    let library = makeLibrary()

    library.show(.tags)

    #expect(library.tagTaskCounts[TagID("home")] == 1)
  }
}
