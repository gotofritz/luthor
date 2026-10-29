import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Observation
import Testing

@testable import LuthorViewModels

@MainActor
private func makeLibrary() -> LibraryViewModel {
  let log = InMemoryEventLog([
    captured("t1", "write report", lamport: 1), scheduled("t1", on: "2026-10-19", lamport: 2),
    projectCreated("p1", "House", lamport: 3), tagCreated("home", "home", lamport: 4),
    captured("t2", "call bank", lamport: 5), prioritized("t2", as: .important, lamport: 6),
    estimated("t2", as: 30, lamport: 7),
  ])
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
    today: { date("2026-10-19") }, now: { 600 })
  library.reload()
  return library
}

/// Whether anything `read` touches is told of a change while `change` runs.
@MainActor
func isTold(of read: () -> Void, whenYou change: () -> Void) -> Bool {
  let told = ChangeFlag()
  withObservationTracking(read) { told.set() }
  change()
  return told.value
}

final class ChangeFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var flag = false
  var value: Bool { lock.withLock { flag } }
  func set() { lock.withLock { flag = true } }
}

@MainActor
@Suite("When a place is presented again with nothing changed")
struct RepeatedPresentTests {
  @Test("the lists and columns shown are not told of a change")
  func listsAndColumnsAreNotToldOfAChange() {
    let library = makeLibrary()
    library.show(.today)

    let told = isTold(
      of: {
        _ = library.columns
        _ = library.tasks
        _ = library.plan
        _ = library.views
        _ = library.settingsByView
        _ = library.tags
        _ = library.projects
      },
      whenYou: { library.present() })

    #expect(!told)
  }

  @Test("a change that does affect a list tells it")
  func aRealChangeIsTold() {
    let library = makeLibrary()
    library.show(.today)

    let told = isTold(of: { _ = library.plan }, whenYou: { library.showNextDay() })

    #expect(told)
  }
}

@MainActor
@Suite("When the day calendar is drawn")
struct DayLayoutCostTests {
  @Test("one layout serves the slots, blocks, sessions and done tasks")
  func oneLayoutServesAllFour() {
    let library = makeLibrary()
    library.show(.today)
    let before = library.layouts.computed

    _ = library.planSlots
    _ = library.planBlocks
    _ = library.planSessions
    _ = library.planDone

    #expect(library.layouts.computed == before + 1)
  }

  @Test("a change to the plan lays the day out again")
  func aChangeToThePlanLaysTheDayOutAgain() {
    let library = makeLibrary()
    library.show(.today)
    #expect(library.planSlots.count == 1)

    library.addToPlan(TaskID("t2"))

    #expect(library.planSlots.count == 2)
  }

  @Test("a drag over the day lays it out for the drag")
  func aDragLaysItOutForTheDrag() {
    let library = makeLibrary()
    library.show(.today)
    let resting = library.planSlots.map(\.start)

    library.dragPreview = (TaskID("t1"), 840)

    #expect(library.planSlots.map(\.start) == [840])
    library.dragPreview = nil
    #expect(library.planSlots.map(\.start) == resting)
  }
}
