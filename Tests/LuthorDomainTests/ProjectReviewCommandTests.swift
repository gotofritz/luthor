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
  @Test("it writes one ProjectReviewIntervalSet")
  func itWritesOneProjectReviewIntervalSet() throws {
    let events = try makeCommands().setReviewInterval(of: ProjectID("p1"), to: .every(days: 3), log: base)

    #expect(events == [reviewIntervalSet("p1", to: .every(days: 3), id: "id-1", lamport: 2)])
  }

  @Test("off leaves the project out of the review")
  func offLeavesTheProjectOut() throws {
    let events = try makeCommands().setReviewInterval(of: ProjectID("p1"), to: .off, log: base)

    #expect(events == [reviewIntervalSet("p1", to: .off, id: "id-1", lamport: 2)])
  }

  @Test("nil clears the interval the project has of its own")
  func nilClearsTheInterval() throws {
    let log = base + [reviewIntervalSet("p1", to: .every(days: 3))]

    let events = try makeCommands().setReviewInterval(of: ProjectID("p1"), to: nil, log: log)

    #expect(events == [reviewIntervalSet("p1", to: nil, id: "id-1", lamport: 3)])
  }

  @Test("the interval it has, or none while it has none, writes nothing")
  func theIntervalItHasWritesNothing() throws {
    let log = base + [reviewIntervalSet("p1", to: .every(days: 3))]

    #expect(try makeCommands().setReviewInterval(of: ProjectID("p1"), to: .every(days: 3), log: log).isEmpty)
    #expect(try makeCommands().setReviewInterval(of: ProjectID("p2"), to: nil, log: log).isEmpty)
  }

  @Test("a project that is not active is refused")
  func aProjectThatIsNotActiveIsRefused() {
    #expect(throws: CommandError.noActiveProject(ProjectID("ghost"))) {
      try makeCommands().setReviewInterval(of: ProjectID("ghost"), to: .off, log: base)
    }
  }
}

@Suite("When a project is marked reviewed by command")
struct ReviewProjectCommandTests {
  @Test("it writes one ProjectReviewed for the day")
  func itWritesOneProjectReviewed() throws {
    let events = try makeCommands().reviewProject(ProjectID("p1"), on: monday, log: base)

    #expect(events == [projectReviewed("p1", on: "2026-10-19", id: "id-1", lamport: 2)])
  }

  @Test("reviewing it again on the same day writes nothing, on another day writes again")
  func reviewingAgainOnTheSameDayWritesNothing() throws {
    let log = base + [projectReviewed("p1", on: "2026-10-19")]

    #expect(try makeCommands().reviewProject(ProjectID("p1"), on: monday, log: log).isEmpty)
    #expect(try makeCommands().reviewProject(ProjectID("p1"), on: date("2026-10-26"), log: log).count == 1)
  }

  @Test("a project whose review is off can still be marked reviewed")
  func aProjectWhoseReviewIsOffCanBeMarked() throws {
    let log = base + [reviewDefaultSet(.off)]

    #expect(try makeCommands().reviewProject(ProjectID("p1"), on: monday, log: log).count == 1)
  }

  @Test("a project that is not active is refused")
  func aProjectThatIsNotActiveIsRefused() {
    #expect(throws: CommandError.noActiveProject(ProjectID("ghost"))) {
      try makeCommands().reviewProject(ProjectID("ghost"), on: monday, log: base)
    }
  }

  @Test("a project that was dropped is refused")
  func aProjectThatWasDroppedIsRefused() {
    #expect(throws: CommandError.projectDropped(ProjectID("p1"))) {
      try makeCommands().reviewProject(ProjectID("p1"), on: monday, log: base + [projectDropped("p1")])
    }
  }
}

@Suite("When a project is put on hold, resumed or dropped by command")
struct ProjectStatusCommandTests {
  @Test("each writes its own event")
  func eachWritesItsOwnEvent() throws {
    let commands = makeCommands()

    #expect(try commands.putOnHold(ProjectID("p1"), log: base) == [projectPutOnHold("p1", id: "id-1", lamport: 2)])
    #expect(try commands.dropProject(ProjectID("p1"), log: base) == [projectDropped("p1", id: "id-2", lamport: 2)])
    #expect(
      try commands.resume(ProjectID("p1"), log: base + [projectPutOnHold("p1")])
        == [projectResumed("p1", id: "id-3", lamport: 4)])
  }

  @Test("a dropped project can be resumed")
  func aDroppedProjectCanBeResumed() throws {
    let events = try makeCommands().resume(ProjectID("p1"), log: base + [projectDropped("p1")])

    #expect(events == [projectResumed("p1", id: "id-1", lamport: 4)])
  }

  @Test("the status a project has writes nothing")
  func theStatusAProjectHasWritesNothing() throws {
    let commands = makeCommands()

    #expect(try commands.resume(ProjectID("p1"), log: base).isEmpty)
    #expect(try commands.putOnHold(ProjectID("p1"), log: base + [projectPutOnHold("p1")]).isEmpty)
    #expect(try commands.dropProject(ProjectID("p1"), log: base + [projectDropped("p1")]).isEmpty)
  }

  @Test("a project that is not active is refused")
  func aProjectThatIsNotActiveIsRefused() {
    let ghost = ProjectID("ghost")
    let completed = base + [projectCompleted("p1")]

    #expect(throws: CommandError.noActiveProject(ghost)) { try makeCommands().putOnHold(ghost, log: base) }
    #expect(throws: CommandError.noActiveProject(ghost)) { try makeCommands().resume(ghost, log: base) }
    #expect(throws: CommandError.noActiveProject(ghost)) { try makeCommands().dropProject(ghost, log: base) }
    #expect(throws: CommandError.noActiveProject(ProjectID("p1"))) {
      try makeCommands().putOnHold(ProjectID("p1"), log: completed)
    }
  }
}
