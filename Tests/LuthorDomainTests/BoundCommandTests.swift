import LuthorDomain
import LuthorTestSupport
import Testing

private let history = [
  captured("t1", "pay rent", lamport: 1),
  prioritized("t1", as: .critical, lamport: 7),
]

@Suite("When commands are bound to the state of the log")
struct BoundCommandTests {
  private func bound() -> Commands {
    Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
      .after(LibraryState.replay(history), lamport: 7)
  }

  @Test("they write the events the whole log would give, without being handed it")
  func sameEventsWithoutTheLog() throws {
    let whole = try Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
      .prioritize(taskID: TaskID("t1"), as: .important, log: history)

    let events = try bound().prioritize(taskID: TaskID("t1"), as: .important, log: [])

    #expect(events == whole)
    #expect(events.map(\.lamport) == [8])
  }

  @Test("a command that writes several events numbers them after the bound counter")
  func severalEventsFollowTheCounter() throws {
    let events = try bound().capture(title: "call bank !a 15m", in: .default, log: [])

    #expect(events.map(\.lamport) == [8, 9, 10])
  }

  @Test("validation reads the bound state")
  func validationUsesTheBoundState() {
    #expect(throws: CommandError.self) {
      try bound().prioritize(taskID: TaskID("missing"), as: .important, log: [])
    }
  }

  @Test("appending the events a command wrote gives the state a replay gives")
  func appendingEqualsReplaying() throws {
    let events = try bound().capture(title: "call bank !a 15m", in: .default, log: [])
    var state = LibraryState.replay(history)

    state.append(events)

    #expect(state == LibraryState.replay(history + events))
  }
}
