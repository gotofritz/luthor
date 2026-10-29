import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

@testable import LuthorViewModels

@MainActor
private func makeLibrary() -> LibraryViewModel {
  let log = InMemoryEventLog([
    captured("t1", "write report", lamport: 1), captured("t2", "call bank", lamport: 2),
    projectCreated("p1", "House", lamport: 3), tagCreated("home", "home", lamport: 4),
  ])
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
    today: { date("2026-10-19") }, now: { 600 })
  library.reload()
  return library
}

/// A read a view makes from the state held, which Observation cannot see into.
private struct StateRead: CustomTestStringConvertible, Sendable {
  let name: String
  let read: @MainActor @Sendable (LibraryViewModel) -> Void
  var testDescription: String { name }
}

private let task = TaskID("t1")
private let project = TaskID("p1")

private let stateReads: [StateRead] = [
  StateRead(name: "a task's tags") { _ = $0.tagItems(of: task) },
  StateRead(name: "how many tasks carry a tag") { _ = $0.tagUseCount(TagID("home")) },
  StateRead(name: "a task's due date") { _ = $0.dueDate(of: task) },
  StateRead(name: "a task's repeat") { _ = $0.repeatRule(of: task) },
  StateRead(name: "a project's review interval") { _ = $0.reviewInterval(of: project) },
  StateRead(name: "a project's own review interval") { _ = $0.reviewOverride(of: project) },
  StateRead(name: "a project's next review") { _ = $0.nextReviewDate(of: project) },
  StateRead(name: "the bulk card") { _ = $0.bulkCard },
]

@MainActor
@Suite("When the log changes")
struct ObservedReadsTests {
  @Test("what a view read from the state held is told, whatever it read", arguments: stateReads)
  fileprivate func aReadFromTheStateIsTold(_ read: StateRead) {
    let library = makeLibrary()

    let told = isTold(
      of: { read.read(library) }, whenYou: { library.setDue(task, to: date("2026-10-20"), isHard: true) })

    #expect(told)
  }
}
