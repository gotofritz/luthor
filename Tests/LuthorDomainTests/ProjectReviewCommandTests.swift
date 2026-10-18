import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

private let base = [
  projectCreated("p1", "Move house", on: "2026-10-12", lamport: 1),
  projectCreated("p2", "Learn Swift", on: "2026-10-14", lamport: 1),
]

private let monday = date("2026-10-19")

@Suite("When the default review interval is set by command")
struct ReviewDefaultCommandTests {
  @Test("it writes one ReviewDefaultSet")
  func itWritesOneReviewDefaultSet() throws {
    let events = try makeCommands().setReviewDefault(.every(days: 14), log: base)

    #expect(events == [reviewDefaultSet(.every(days: 14), id: "id-1", lamport: 2)])
  }

  @Test("off turns review off for every project")
  func offTurnsReviewOff() throws {
    let events = try makeCommands().setReviewDefault(.off, log: base)

    #expect(events == [reviewDefaultSet(.off, id: "id-1", lamport: 2)])
  }

  @Test("no days, or fewer, is written as off", arguments: [0, -1])
  func noDaysIsWrittenAsOff(days: Int) throws {
    let events = try makeCommands().setReviewDefault(.every(days: days), log: base)

    #expect(events == [reviewDefaultSet(.off, id: "id-1", lamport: 2)])
  }

  @Test("the interval it has writes nothing")
  func theIntervalItHasWritesNothing() throws {
    #expect(try makeCommands().setReviewDefault(.weekly, log: base).isEmpty)
    #expect(try makeCommands().setReviewDefault(.off, log: base + [reviewDefaultSet(.off)]).isEmpty)
  }
}

@Suite("When a project's review interval is set by command")
struct ReviewIntervalCommandTests {
  @Test("it writes one ReviewIntervalSet")
  func itWritesOneProjectReviewIntervalSet() throws {
    let events = try makeCommands().setReviewInterval(of: TaskID("p1"), to: .every(days: 3), log: base)

    #expect(events == [reviewIntervalSet("p1", to: .every(days: 3), id: "id-1", lamport: 2)])
  }

  @Test("off leaves the project out of the review")
  func offLeavesTheProjectOut() throws {
    let events = try makeCommands().setReviewInterval(of: TaskID("p1"), to: .off, log: base)

    #expect(events == [reviewIntervalSet("p1", to: .off, id: "id-1", lamport: 2)])
  }

  @Test("nil clears the interval the project has of its own")
  func nilClearsTheInterval() throws {
    let log = base + [reviewIntervalSet("p1", to: .every(days: 3))]

    let events = try makeCommands().setReviewInterval(of: TaskID("p1"), to: nil, log: log)

    #expect(events == [reviewIntervalSet("p1", to: nil, id: "id-1", lamport: 3)])
  }

  @Test("the interval it has, or none while it has none, writes nothing")
  func theIntervalItHasWritesNothing() throws {
    let log = base + [reviewIntervalSet("p1", to: .every(days: 3))]

    #expect(try makeCommands().setReviewInterval(of: TaskID("p1"), to: .every(days: 3), log: log).isEmpty)
    #expect(try makeCommands().setReviewInterval(of: TaskID("p2"), to: nil, log: log).isEmpty)
  }

  @Test("a project that is not active is refused")
  func aProjectThatIsNotActiveIsRefused() {
    #expect(throws: CommandError.noActiveProject(TaskID("ghost"))) {
      try makeCommands().setReviewInterval(of: TaskID("ghost"), to: .off, log: base)
    }
  }
}

@Suite("When a project is marked reviewed by command")
struct ReviewProjectCommandTests {
  @Test("it writes one TaskReviewed for the day")
  func itWritesOneProjectReviewed() throws {
    let events = try makeCommands().reviewProject(TaskID("p1"), on: monday, log: base)

    #expect(events == [projectReviewed("p1", on: "2026-10-19", id: "id-1", lamport: 2)])
  }

  @Test("reviewing it again on the same day writes nothing, on another day writes again")
  func reviewingAgainOnTheSameDayWritesNothing() throws {
    let log = base + [projectReviewed("p1", on: "2026-10-19")]

    #expect(try makeCommands().reviewProject(TaskID("p1"), on: monday, log: log).isEmpty)
    #expect(try makeCommands().reviewProject(TaskID("p1"), on: date("2026-10-26"), log: log).count == 1)
  }

  @Test("a project whose review is off can still be marked reviewed")
  func aProjectWhoseReviewIsOffCanBeMarked() throws {
    let log = base + [reviewDefaultSet(.off)]

    #expect(try makeCommands().reviewProject(TaskID("p1"), on: monday, log: log).count == 1)
  }

  @Test("a project that is not active is refused")
  func aProjectThatIsNotActiveIsRefused() {
    #expect(throws: CommandError.noActiveProject(TaskID("ghost"))) {
      try makeCommands().reviewProject(TaskID("ghost"), on: monday, log: base)
    }
  }

  @Test("a project that was dropped is refused")
  func aProjectThatWasDroppedIsRefused() {
    #expect(throws: CommandError.noActiveProject(TaskID("p1"))) {
      try makeCommands().reviewProject(TaskID("p1"), on: monday, log: base + [projectDropped("p1")])
    }
  }
}

@Suite("When a project is dropped by command")
struct ProjectStatusCommandTests {
  @Test("it writes a TaskDropped event")
  func itWritesAProjectDroppedEvent() throws {
    #expect(
      try makeCommands().dropProject(TaskID("p1"), log: base) == [projectDropped("p1", id: "id-1", lamport: 2)])
  }

  @Test("a dropped project is refused, as it is not open")
  func droppingADroppedProjectIsRefused() {
    #expect(throws: CommandError.noActiveProject(TaskID("p1"))) {
      try makeCommands().dropProject(TaskID("p1"), log: base + [projectDropped("p1")])
    }
  }

  @Test("a project that is not active is refused")
  func aProjectThatIsNotActiveIsRefused() {
    let completed = base + [projectCompleted("p1")]

    #expect(throws: CommandError.noActiveProject(TaskID("ghost"))) {
      try makeCommands().dropProject(TaskID("ghost"), log: base)
    }
    #expect(throws: CommandError.noActiveProject(TaskID("p1"))) {
      try makeCommands().dropProject(TaskID("p1"), log: completed)
    }
  }
}
