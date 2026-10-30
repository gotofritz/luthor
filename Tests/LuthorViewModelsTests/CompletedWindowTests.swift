import LuthorDomain
import LuthorTestSupport
import LuthorViewModels
import Testing

/// Today is 2026-10-19. "milk" was done today, "bank" 2 days ago, "post" 5 days ago, "tax" 20 days ago, and
/// "old" was done before the day was kept.
private let windowLog = [
  captured("t1", "milk", lamport: 1), completed("t1", on: "2026-10-19", lamport: 2),
  captured("t2", "bank", lamport: 3), completed("t2", on: "2026-10-17", lamport: 4),
  captured("t3", "post", lamport: 5), completed("t3", on: "2026-10-14", lamport: 6),
  captured("t4", "tax", lamport: 7), completed("t4", on: "2026-09-29", lamport: 8),
  captured("t5", "old", lamport: 9), completed("t5", lamport: 10),
  captured("t6", "open", lamport: 11),
]

@MainActor
private func listed(_ window: CompletedWindow) -> Set<TaskID> {
  let (library, _) = makeInbox(windowLog)
  library.showCompleted = true
  library.setCompletedWindow(window, ofList: library.taskListID)
  return library.completedTaskIDs
}

@MainActor
@Suite("When the completed tasks of a list are narrowed to a stretch of days")
struct CompletedWindowTests {
  @Test("all lists every completed task, those with no day too")
  func all() {
    #expect(listed(.all) == Set(["t1", "t2", "t3", "t4", "t5"].map(TaskID.init)))
  }

  @Test("the past day lists what was done today and yesterday")
  func pastDay() {
    #expect(listed(.pastDay) == Set([TaskID("t1")]))
  }

  @Test("the past 3 days lists what was done within three days")
  func past3Days() {
    #expect(listed(.past3Days) == Set(["t1", "t2"].map(TaskID.init)))
  }

  @Test("the past week lists what was done within seven days")
  func pastWeek() {
    #expect(listed(.pastWeek) == Set(["t1", "t2", "t3"].map(TaskID.init)))
  }

  @Test("none lists no completed task, though completed tasks are shown")
  func none() {
    #expect(listed(.none).isEmpty)
  }

  @Test("the open tasks stay in every case")
  func openTasksStay() {
    let (library, _) = makeInbox(windowLog)
    library.showCompleted = true
    library.setCompletedWindow(.none, ofList: library.taskListID)

    #expect(library.tasks.map(\.title) == ["open"])
  }

  @Test("a list shows all of them until it is narrowed, and each place keeps its own")
  func placesAreIndependent() {
    let (library, _) = makeInbox(windowLog)

    library.setCompletedWindow(.pastWeek, ofList: "project-p1")

    #expect(library.completedWindow(ofList: "top") == .pastWeek)
    #expect(library.completedWindow(ofList: library.taskListID) == .all)
  }
}
