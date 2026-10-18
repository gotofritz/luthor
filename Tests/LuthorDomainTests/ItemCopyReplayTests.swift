import LuthorDomain
import LuthorTestSupport
import Testing

private let trip = [
  projectCreated("p1", "Trip", lamport: 1),
  captured("t1", "book flights", under: "p1", lamport: 2),
  captured("t2", "pack", under: "p1", lamport: 3),
  captured("t3", "cancelled idea", under: "p1", lamport: 4),
  dropped("t3", lamport: 5),
  completed("t2", lamport: 6),
  projectCreated("p2", "Visas", under: "p1", lamport: 7),
  captured("t4", "passport", under: "p2", lamport: 8),
]

@Suite("When a project is duplicated")
struct DuplicateContainerReplayTests {
  static let events = trip + [duplicated("p1", as: "c1", lamport: 20)]

  @Test("the copy holds a copy of each task and sub-project that was not given up, all open")
  func theCopyHoldsTheStructure() throws {
    let state = LibraryState.replay(Self.events)

    let copy = try #require(state.view(.default).projects.first { $0.id == TaskID("c1") })
    #expect(copy.title == "Trip")
    #expect(copy.tasks.map(\.title) == ["book flights", "pack"])
    let visas = try #require(state.view(.default).projects.first { $0.parentID == TaskID("c1") })
    #expect(visas.title == "Visas")
    #expect(visas.tasks.map(\.title) == ["passport"])
  }

  @Test("the original is left as it was")
  func theOriginalIsUntouched() throws {
    let state = LibraryState.replay(Self.events)

    let original = try #require(state.view(.default).projects.first { $0.id == TaskID("p1") })
    #expect(original.tasks.map(\.id) == [TaskID("t1")])
    #expect(state.view(.default).completedTasks.map(\.item.id) == [TaskID("t3"), TaskID("t2")])
  }

  @Test("the copies of the tasks get IDs worked out from the copy, so devices agree")
  func copiedIDsAreWorkedOut() throws {
    let state = LibraryState.replay(Self.events)

    let copy = try #require(state.view(.default).projects.first { $0.id == TaskID("c1") })
    let expected = ["t1", "t2"].map { TaskID.copied(TaskID($0), under: TaskID("c1")) }
    #expect(copy.tasks.map(\.id) == expected)
  }

  @Test("replaying the events in another arrival order gives the same copy")
  func arrivalOrderDoesNotMatter() {
    let state = LibraryState.replay(Self.events)
    let shuffled = LibraryState.replay(Self.events.reversed())

    #expect(shuffled.view(.default).projects == state.view(.default).projects)
  }

  @Test("the copy keeps the priority and estimate of what it copies")
  func theCopyKeepsTheFields() throws {
    let events =
      trip + [
        prioritized("t1", as: .important, lamport: 9), estimated("t1", as: 30, lamport: 10),
        duplicated("p1", as: "c1", lamport: 20),
      ]

    let state = LibraryState.replay(events)

    let copy = try #require(state.view(.default).projects.first { $0.id == TaskID("c1") })
    #expect(copy.tasks.first?.priority == .important)
    #expect(copy.tasks.first?.estimate == 30)
  }
}

@Suite("When a repeating project is completed")
struct RecurContainerReplayTests {
  static let events =
    trip + [
      dueSet("p1", on: "2026-10-26", lamport: 9),
      dueSet("t1", on: "2026-10-27", lamport: 10),
      repeatSet("p1", RepeatRule(every: 1, unit: .week), lamport: 11),
      completed("p1", lamport: 12),
      recurred("p1", as: "n1", due: "2026-11-02", lamport: 13),
    ]

  @Test("the next project holds the tasks of this one, open and with no due dates")
  func theNextProjectHoldsTheTasks() throws {
    let state = LibraryState.replay(Self.events)

    let next = try #require(state.view(.default).projects.first { $0.id == TaskID("n1") })
    #expect(next.tasks.map(\.title) == ["book flights", "pack"])
    #expect(state.dueDate(of: TaskID("n1"))?.date == date("2026-11-02"))
    #expect(next.tasks.allSatisfy { state.dueDate(of: $0.id) == nil })
  }

  @Test("the next project repeats too")
  func theNextProjectRepeats() {
    let state = LibraryState.replay(Self.events)

    #expect(state.repeatRule(of: TaskID("n1")) == RepeatRule(every: 1, unit: .week))
  }
}
