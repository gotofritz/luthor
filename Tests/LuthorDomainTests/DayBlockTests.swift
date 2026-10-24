import LuthorDomain
import LuthorTestSupport
import Testing

private let monday = date("2026-10-19")

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a day has blocks of untracked time")
struct DayBlockTests {
  private func plan(_ events: [EventEnvelope]) -> DayPlan {
    LibraryState.replay(events).plan(for: .default, on: monday, today: monday)
  }

  @Test("the day's plan lists its blocks and no other day's")
  func thePlanListsItsBlocks() {
    let events = [
      blockSet("b1", "Lunch", 750, 810, on: "2026-10-19", lamport: 1),
      blockSet("b2", "Gym", 600, 660, on: "2026-10-20", lamport: 2),
    ]

    #expect(plan(events).blocks == [DayBlock(id: BlockID("b1"), title: "Lunch", start: 750, end: 810)])
  }

  @Test("setting a block again changes it, and removing it takes it off the day")
  func settingAgainChangesAndRemovingTakesOff() {
    let changed = [
      blockSet("b1", "Lunch", 750, 810, on: "2026-10-19", lamport: 1),
      blockSet("b1", "Walk", 720, 780, on: "2026-10-19", lamport: 2),
    ]
    let removed = changed + [blockRemoved("b1", lamport: 3)]

    #expect(plan(changed).blocks.map(\.title) == ["Walk"])
    #expect(plan(removed).blocks.isEmpty)
  }

  @Test("tasks flow round a block")
  func tasksFlowRoundABlock() {
    let events = [
      captured("a", "Write", lamport: 1), estimated("a", as: 90, lamport: 2),
      scheduled("a", on: "2026-10-19", lamport: 3),
      blockSet("b1", "Lunch", 600, 660, on: "2026-10-19", lamport: 4),
    ]

    let slot = plan(events).slots().first
    #expect(slot?.start == 660)
  }

  @Test("adding a block writes it with the title trimmed")
  func addingABlock() throws {
    let log: [EventEnvelope] = []
    let events = try makeCommands().addBlock(
      title: "  Lunch ", hours: DayHours(start: 750, end: 810), for: ViewID.default, on: monday, log: log)

    #expect(LibraryState.replay(log + events).blocks(in: ViewID.default, on: monday).map(\.title) == ["Lunch"])
  }

  @Test("a blank title becomes Break and bad hours are refused")
  func blankTitleAndBadHours() throws {
    let log: [EventEnvelope] = []
    let events = try makeCommands().addBlock(
      title: " ", hours: DayHours(start: 750, end: 810), for: ViewID.default, on: monday, log: log)
    #expect(LibraryState.replay(events).blocks(in: ViewID.default, on: monday).map(\.title) == ["Break"])
    #expect(throws: CommandError.invalidHours) {
      try makeCommands().addBlock(
        title: "x", hours: DayHours(start: 900, end: 800), for: ViewID.default, on: monday, log: log)
    }
  }

  @Test("updating moves a block, an unchanged update writes nothing and an unknown block is refused")
  func updatingABlock() throws {
    let log = [blockSet("b1", "Lunch", 750, 810, on: "2026-10-19", lamport: 1)]
    let moved = try makeCommands().updateBlock(BlockID("b1"), title: "Lunch", start: 780, end: 840, log: log)
    let same = try makeCommands().updateBlock(BlockID("b1"), title: "Lunch", start: 750, end: 810, log: log)

    #expect(LibraryState.replay(log + moved).blocks(in: ViewID.default, on: monday).first?.start == 780)
    #expect(same.isEmpty)
    #expect(throws: CommandError.noBlock(BlockID("zz"))) {
      try makeCommands().updateBlock(BlockID("zz"), title: "x", start: 1, end: 2, log: log)
    }
  }

  @Test("removing a block takes it off, and an unknown block is refused")
  func removingABlock() throws {
    let log = [blockSet("b1", "Lunch", 750, 810, on: "2026-10-19", lamport: 1)]
    let events = try makeCommands().removeBlock(BlockID("b1"), log: log)

    #expect(LibraryState.replay(log + events).blocks(in: ViewID.default, on: monday).isEmpty)
    #expect(throws: CommandError.noBlock(BlockID("zz"))) { try makeCommands().removeBlock(BlockID("zz"), log: log) }
  }
}

@Suite("When tasks of a day would overlap")
struct NoOverlapTests {
  private let tasks = [
    captured("t1", "write report", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
    estimated("t1", as: 60, lamport: 3), scheduled("t1", on: "2026-10-19", lamport: 4),
    captured("t2", "call bank", lamport: 5), prioritized("t2", as: .important, lamport: 6),
    estimated("t2", as: 30, lamport: 7), scheduled("t2", on: "2026-10-19", lamport: 8),
  ]

  private func slots(_ more: [EventEnvelope]) -> [PlanSlot] {
    LibraryState.replay(tasks + more).plan(for: .default, on: monday, today: monday).slots()
  }

  @Test("a task given a time in another's way moves to the end of it")
  func aTaskInTheWayIsPushedLater() {
    let result = slots([
      startSet("t1", 600, on: "2026-10-19", lamport: 9), startSet("t2", 630, on: "2026-10-19", lamport: 10),
    ])

    #expect(result.map(\.start) == [600, 660])
    #expect(result.map(\.end) == [660, 690])
  }

  @Test("a task dropped on another's place wins it and the other moves to the end of it")
  func aDroppedTaskWinsItsPlace() {
    let plan = LibraryState.replay(
      tasks + [startSet("t1", 600, on: "2026-10-19", lamport: 9), startSet("t2", 800, on: "2026-10-19", lamport: 10)]
    ).plan(for: .default, on: monday, today: monday)

    let result = plan.slots(moving: TaskID("t2"), to: 620)

    #expect(result.map(\.entry.task.id) == [TaskID("t2"), TaskID("t1")])
    #expect(result.map(\.start) == [620, 650])
  }

  @Test("a longer estimate pushes the tasks after it later")
  func aLongerEstimatePushesTheRestLater() {
    let before = slots([
      startSet("t1", 600, on: "2026-10-19", lamport: 9), startSet("t2", 660, on: "2026-10-19", lamport: 10),
    ])
    let after = slots([
      startSet("t1", 600, on: "2026-10-19", lamport: 9), startSet("t2", 660, on: "2026-10-19", lamport: 10),
      estimated("t1", as: 120, lamport: 11),
    ])

    #expect(before.map(\.start) == [600, 660])
    #expect(after.map(\.start) == [600, 720])
  }

  @Test("a task whose time falls on a block moves to the end of the block")
  func aTaskOnABlockMovesPastIt() {
    let result = slots([
      startSet("t1", 700, on: "2026-10-19", lamport: 9),
      blockSet("b1", "Lunch", 720, 780, on: "2026-10-19", lamport: 10),
    ])

    #expect(result.first { $0.entry.task.title == "write report" }?.start == 780)
  }
}
