import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When a library is exported and imported again")
struct LibraryExportTests {
  private let commands = Commands(deviceID: DeviceID("other"), ids: SequentialIDs())

  private func imported(_ events: [EventEnvelope], into log: [EventEnvelope] = []) throws -> LibraryState {
    let export = LibraryState.replay(events).export()
    return LibraryState.replay(log + (try commands.importLibrary(export, log: log)))
  }

  private let family: [EventEnvelope] = [
    projectCreated("p1", "Holiday", kind: .sequential, on: "2026-10-12", lamport: 1),
    captured("t1", "Book flights", under: "p1", lamport: 2),
    captured("t2", "Pack", under: "p1", lamport: 3),
    captured("t3", "Buy milk", lamport: 4),
    prioritized("t3", as: .critical, lamport: 5),
    estimated("t3", as: 15, lamport: 6),
    completed("t1", lamport: 7),
    projectCompleted("p1", lamport: 8),
  ]

  @Test("the export is the same after a round trip through an empty library")
  func theExportSurvivesARoundTrip() throws {
    let before = LibraryState.replay(family).export()

    #expect(try imported(family).export() == before)
  }

  @Test("an item finished on its own stays so, and one a project took along is listed with that project")
  func finishedItemsKeepTheirWay() {
    let items = LibraryState.replay(family).export().items

    #expect(items.map(\.id.rawValue) == ["p1", "t2", "t1", "t3"])
    #expect(items.map(\.status) == [.completed, .completed, .completed, .open])
    #expect(items.map { $0.finishedWith?.rawValue } == [nil, "p1", nil, nil])
  }

  @Test("priority, estimate, kind and the day created are carried")
  func fieldsAreCarried() throws {
    let state = try imported(family)

    #expect(state.export().items.first { $0.id.rawValue == "t3" }?.priority == .critical)
    #expect(state.export().items.first { $0.id.rawValue == "t3" }?.estimate == 15)
    #expect(state.export().items.first { $0.id.rawValue == "p1" }?.kind == .sequential)
    #expect(state.export().items.first { $0.id.rawValue == "p1" }?.createdOn == date("2026-10-12"))
  }

  @Test("settings and the weekly project review are carried")
  func settingsAndReviewsAreCarried() throws {
    let events = [
      projectCreated("p1", "Holiday", lamport: 1),
      settingChanged(.themeAccent, to: "plum", view: "default", lamport: 2),
      settingChanged(.bufferPercentage, to: "20", lamport: 3),
      reviewDefaultSet(.every(days: 14), lamport: 4),
      reviewIntervalSet("p1", to: .every(days: 3), lamport: 5),
      projectReviewed("p1", on: "2026-10-19", lamport: 6),
      reviewDateSet("p1", to: "2026-10-30", lamport: 7),
    ]
    let before = LibraryState.replay(events)

    let after = try imported(events)

    #expect(after.export() == before.export())
    #expect(after.defaultReviewInterval == .every(days: 14))
    #expect(after.nextReviewDate(of: TaskID("p1")) == date("2026-10-30"))
  }

  @Test("importing what the library already has adds no events")
  func importingTwiceAddsNothing() throws {
    let export = LibraryState.replay(family).export()

    #expect(try commands.importLibrary(export, log: family).isEmpty)
  }

  @Test("importing continues the Lamport counter of the log")
  func importContinuesTheCounter() throws {
    let export = LibraryState.replay([captured("t9", "new", lamport: 1)]).export()
    let log = [captured("t1", "old", lamport: 40)]

    let events = try commands.importLibrary(export, log: log)

    #expect(events.map(\.lamport) == [41])
  }

  @Test("an item in a view the export does not list is an error")
  func anItemInAnUnknownViewIsAnError() {
    let export = LibraryExport(
      views: [], tags: [], items: [ExportedItem(id: TaskID("t1"), title: "x", view: ViewID("nowhere"))])

    #expect(throws: CommandError.noView(ViewID("nowhere"))) { try commands.importLibrary(export, log: []) }
  }

  @Test("a renamed default view keeps its name")
  func aRenamedDefaultViewKeepsItsName() throws {
    let events = [viewRenamed("default", to: "Home", lamport: 1), captured("t1", "milk", lamport: 2)]

    let after = try imported(events)

    #expect(after.export().views.first?.name == "Home")
    #expect(after.export() == LibraryState.replay(events).export())
  }

  @Test("a task finished in a view its project later left is exported without that parent")
  func aFinishedTaskLeftBehindInAnotherView() throws {
    let events = [
      viewCreated("work", "Work", lamport: 1),
      projectCreated("p1", "Holiday", lamport: 2),
      captured("t1", "Book flights", under: "p1", lamport: 3),
      completed("t1", lamport: 4),
      movedToView("p1", toView: "work", lamport: 5),
    ]

    let before = LibraryState.replay(events).export()

    #expect(before.items.first { $0.id.rawValue == "t1" }?.parent == nil)
    #expect(try imported(events).export() == before)
  }

  @Test("two libraries that differ say where")
  func differencesAreNamed() {
    let one = LibraryState.replay([captured("t1", "milk", lamport: 1)]).export()
    let other = LibraryState.replay([captured("t1", "milk", lamport: 1), estimated("t1", as: 5, lamport: 2)]).export()
    let more = LibraryState.replay([captured("t1", "milk", lamport: 1), captured("t2", "eggs", lamport: 2)]).export()

    #expect(one.firstDifference(from: one) == nil)
    #expect(one.firstDifference(from: other) == "\"milk\" (t1) differs in estimate")
    #expect(one.firstDifference(from: more) == "1 items became 2")
  }
}
