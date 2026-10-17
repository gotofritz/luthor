import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a task is prioritised by command")
struct PrioritizeCommandTests {
  static let log = [captured("t1", "pay rent", lamport: 1)]

  @Test("it writes one TaskPrioritized")
  func prioritizeWritesTaskPrioritized() throws {
    let events = try makeCommands().prioritize(taskID: TaskID("t1"), as: .critical, log: Self.log)

    #expect(events == [prioritized("t1", as: .critical, id: "id-1", lamport: 2)])
  }

  @Test("clearing the priority of a prioritised task writes one TaskPrioritized without a priority")
  func clearingWritesTaskPrioritizedWithoutPriority() throws {
    let log = Self.log + [prioritized("t1", as: .critical, lamport: 2)]

    let events = try makeCommands().prioritize(taskID: TaskID("t1"), as: nil, log: log)

    #expect(events == [prioritized("t1", as: nil, id: "id-1", lamport: 3)])
  }

  @Test("giving a task the priority it has writes nothing")
  func samePriorityWritesNothing() throws {
    let log = Self.log + [prioritized("t1", as: .critical, lamport: 2)]

    #expect(try makeCommands().prioritize(taskID: TaskID("t1"), as: .critical, log: log) == [])
  }

  @Test("clearing the priority of a task without one writes nothing")
  func clearingNothingWritesNothing() throws {
    #expect(try makeCommands().prioritize(taskID: TaskID("t1"), as: nil, log: Self.log) == [])
  }

  @Test("a task that is not open is refused")
  func unknownTaskIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().prioritize(taskID: TaskID("t9"), as: .critical, log: Self.log)
    }
  }
}
