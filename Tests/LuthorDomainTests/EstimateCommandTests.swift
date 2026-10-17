import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a task is given an estimate by command")
struct EstimateCommandTests {
  static let log = [captured("t1", "pay rent", lamport: 1)]

  @Test("it writes one TaskEstimated")
  func estimateWritesTaskEstimated() throws {
    let events = try makeCommands().estimate(taskID: TaskID("t1"), as: 15, log: Self.log)

    #expect(events == [estimated("t1", as: 15, id: "id-1", lamport: 2)])
  }

  @Test("clearing the estimate of an estimated task writes one TaskEstimated without minutes")
  func clearingWritesTaskEstimatedWithoutMinutes() throws {
    let log = Self.log + [estimated("t1", as: 15, lamport: 2)]

    let events = try makeCommands().estimate(taskID: TaskID("t1"), as: nil, log: log)

    #expect(events == [estimated("t1", as: nil, id: "id-1", lamport: 3)])
  }

  @Test("giving a task the estimate it has writes nothing")
  func sameEstimateWritesNothing() throws {
    let log = Self.log + [estimated("t1", as: 15, lamport: 2)]

    #expect(try makeCommands().estimate(taskID: TaskID("t1"), as: 15, log: log) == [])
  }

  @Test("clearing the estimate of a task without one writes nothing")
  func clearingNothingWritesNothing() throws {
    #expect(try makeCommands().estimate(taskID: TaskID("t1"), as: nil, log: Self.log) == [])
  }

  @Test("a task that is not open is refused")
  func unknownTaskIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().estimate(taskID: TaskID("t9"), as: 15, log: Self.log)
    }
  }
}
