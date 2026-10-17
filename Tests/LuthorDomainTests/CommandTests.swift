import LuthorDomain
import LuthorTestSupport
import Testing

@Suite struct CaptureCommandTests {
  @Test func captureOnEmptyLogStartsLamportAtOne() throws {
    let commands = Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())

    let events = try commands.capture(title: "buy milk", log: [])

    #expect(
      events == [
        EventEnvelope(
          id: EventID("id-1"),
          deviceID: DeviceID("mac"),
          lamport: 1,
          payload: .taskCaptured(TaskCaptured(taskID: TaskID("id-2"), title: "buy milk"))
        )
      ])
  }

  @Test func captureFollowsTheHighestLamportInTheLog() throws {
    let commands = Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
    let log = [captured("t1", "a", lamport: 7), captured("t2", "b", lamport: 3)]

    let events = try commands.capture(title: "c", log: log)

    #expect(events.map(\.lamport) == [8])
  }

  @Test func captureTrimsSurroundingWhitespace() throws {
    let commands = Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())

    let events = try commands.capture(title: "  buy milk \n", log: [])

    #expect(events.map(\.payload) == [.taskCaptured(TaskCaptured(taskID: TaskID("id-2"), title: "buy milk"))])
  }

  @Test(arguments: ["", "   ", "\n\t"])
  func captureRejectsABlankTitle(title: String) {
    let commands = Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())

    #expect(throws: CommandError.blankTitle) {
      try commands.capture(title: title, log: [])
    }
  }
}

@Suite struct CompleteCommandTests {
  static let log = [
    captured("abc123", "buy milk", lamport: 1),
    captured("abd456", "call mum", lamport: 2),
    captured("ffe789", "pay rent", lamport: 3),
    completed("ffe789", lamport: 4),
  ]

  @Test(arguments: ["abc", "ABC", "abc123"])
  func completeFindsTheOpenTaskByIDPrefix(prefix: String) throws {
    let commands = Commands(deviceID: DeviceID("air"), ids: SequentialIDs())

    let events = try commands.complete(idPrefix: prefix, log: Self.log)

    #expect(
      events == [
        EventEnvelope(
          id: EventID("id-1"),
          deviceID: DeviceID("air"),
          lamport: 5,
          payload: .taskCompleted(TaskCompleted(taskID: TaskID("abc123")))
        )
      ])
  }

  @Test func completeRejectsAnAmbiguousPrefix() {
    let commands = Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())

    #expect(throws: CommandError.ambiguousPrefix("ab", matches: [TaskID("abc123"), TaskID("abd456")])) {
      try commands.complete(idPrefix: "ab", log: Self.log)
    }
  }

  @Test(arguments: ["zzz", "", "ffe"])
  func completeRejectsAPrefixMatchingNoOpenTask(prefix: String) {
    let commands = Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())

    #expect(throws: CommandError.noOpenTask(prefix)) {
      try commands.complete(idPrefix: prefix, log: Self.log)
    }
  }
}
