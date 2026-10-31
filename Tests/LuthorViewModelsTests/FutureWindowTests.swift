import LuthorDomain
import LuthorTestSupport
import LuthorViewModels
import Testing

/// Today is 2026-10-19. "none" has no date, "soon" is due in 2 days, "week" is scheduled in 5 days, "month" is due
/// in 20 days, "far" in 90 days, "mixed" is due in 90 days but scheduled tomorrow, and "late" was due 3 days ago.
private let futureLog = [
  captured("t0", "none", lamport: 1),
  captured("t1", "soon", lamport: 2), dueSet("t1", on: "2026-10-21", lamport: 3),
  captured("t2", "week", lamport: 4), scheduled("t2", on: "2026-10-24", lamport: 5),
  captured("t3", "month", lamport: 6), dueSet("t3", on: "2026-11-08", lamport: 7),
  captured("t4", "far", lamport: 8), dueSet("t4", on: "2027-01-17", lamport: 9),
  captured("t5", "mixed", lamport: 10), dueSet("t5", on: "2027-01-17", lamport: 11),
  scheduled("t5", on: "2026-10-20", lamport: 12),
  captured("t6", "late", lamport: 13), dueSet("t6", on: "2026-10-16", lamport: 14),
]

@MainActor
private func listed(_ window: FutureWindow) -> Set<String> {
  let (library, _) = makeInbox(futureLog)
  library.setFutureWindow(window, ofList: library.taskListID)
  return Set(library.tasks.map(\.title))
}

@MainActor
@Suite("When the future tasks of a list are narrowed to a stretch of days")
struct FutureWindowTests {
  @Test("all lists every task")
  func all() {
    #expect(listed(.all) == ["none", "soon", "week", "month", "far", "mixed", "late"])
  }

  @Test("1 day lists what is dated by tomorrow, the sooner of due and scheduled counting")
  func oneDay() {
    #expect(listed(.day) == ["none", "mixed", "late"])
  }

  @Test("1 week lists what is dated within seven days")
  func oneWeek() {
    #expect(listed(.week) == ["none", "soon", "week", "mixed", "late"])
  }

  @Test("1 month lists what is dated within a month")
  func oneMonth() {
    #expect(listed(.month) == ["none", "soon", "week", "month", "mixed", "late"])
  }

  @Test("none lists no task dated after today, and those with no date stay")
  func none() {
    #expect(listed(.none) == ["none", "late"])
  }

  @Test("a list shows every task until a window is chosen")
  func defaultIsAll() {
    let (library, _) = makeInbox(futureLog)
    #expect(library.futureWindow(ofList: library.taskListID) == .all)
    #expect(library.tasks.count == 7)
  }

  @Test("each place keeps its own window and tells the app when one changes")
  func perPlace() {
    let (library, _) = makeInbox(futureLog)
    var saved: [String: FutureWindow] = [:]
    library.onFutureWindowsChanged = { saved = $0 }

    library.setFutureWindow(.week, ofList: "priorities")

    #expect(library.futureWindow(ofList: "priorities") == .week)
    #expect(library.futureWindow(ofList: library.taskListID) == .all)
    #expect(saved == ["priorities": .week])
  }

  @Test("a window given at start is kept")
  func givenAtStart() {
    let log = InMemoryEventLog(futureLog)
    let library = LibraryViewModel(
      log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()), today: { date("2026-10-19") },
      futureWindows: ["tasks-inbox": .none])
    library.reload()

    #expect(Set(library.tasks.map(\.title)) == ["none", "late"])
  }
}
