import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Observation
import Testing

private final class Told: @unchecked Sendable {
  var value = false
}

@MainActor
private func makeLibrary(_ events: [EventEnvelope]) -> (LibraryViewModel, InMemoryEventLog) {
  let log = InMemoryEventLog(events)
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
    today: { date("2026-10-19") })
  library.reload()
  return (library, log)
}

@MainActor
@Suite("When the log is reloaded")
struct ReloadViewModelTests {
  @Test("a log that has not changed leaves the window as it is")
  func unchangedLogTellsNoOne() {
    let (library, _) = makeLibrary([captured("t1", "buy milk", lamport: 1)])
    let told = Told()

    withObservationTracking {
      _ = library.tasks
      _ = library.views
    } onChange: {
      told.value = true
    }
    library.reload()

    #expect(!told.value)
  }

  @Test("an event another process appended is shown")
  func outsideEventIsShown() {
    let (library, log) = makeLibrary([captured("t1", "buy milk", lamport: 1)])

    log.events.append(captured("t2", "book flights", lamport: 2))
    library.reload()

    #expect(library.tasks.map(\.title) == ["buy milk", "book flights"])
  }

  @Test("the first reload of an empty log still fills the views")
  func emptyLogFillsViews() {
    let (library, _) = makeLibrary([])

    #expect(library.views == [ViewItem(id: .default, name: "Default")])
  }
}

@MainActor
@Suite("When an action is taken")
struct ActionViewModelTests {
  @Test("it does not read the log, whose state is already held")
  func actionDoesNotReadTheLog() {
    let (library, log) = makeLibrary([captured("t1", "buy milk", lamport: 1)])
    log.readFailure = .ioFailure("disk gone")

    library.prioritize(TaskID("t1"), as: .critical)

    #expect(library.errorMessage == nil)
    #expect(library.tasks.first?.priority == .critical)
  }

  @Test("its events follow the highest Lamport counter seen at the last reload")
  func eventsFollowTheCounter() {
    let (library, log) = makeLibrary([captured("t1", "buy milk", lamport: 41)])

    library.prioritize(TaskID("t1"), as: .critical)

    #expect(log.events.last?.lamport == 42)
  }

  @Test("an event written outside is seen after the next reload, and the counter follows it")
  func outsideEventMovesTheCounter() {
    let (library, log) = makeLibrary([captured("t1", "buy milk", lamport: 1)])
    log.events.append(captured("t2", "book flights", device: "phone", lamport: 9))
    library.reload()

    library.prioritize(TaskID("t2"), as: .critical)

    #expect(log.events.last?.lamport == 10)
  }
}
