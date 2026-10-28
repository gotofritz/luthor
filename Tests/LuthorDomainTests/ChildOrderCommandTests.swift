import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

private let log = [
  projectCreated("p1", "Errands", lamport: 1),
  captured("t1", "banana", under: "p1", lamport: 2),
  captured("t2", "Cherry", under: "p1", lamport: 3),
  captured("t3", "apple", under: "p1", lamport: 4),
  captured("t4", "date", under: "p1", lamport: 5),
  prioritized("t1", as: .optional, lamport: 6),
  prioritized("t2", as: .critical, lamport: 7),
  prioritized("t3", as: .someday, lamport: 8),
]

@Suite("When a child of a project is moved up or down by command")
struct MoveChildCommandTests {
  @Test("down swaps it with the one after")
  func movingDown() throws {
    let events = try makeCommands().moveChild(TaskID("t1"), by: 1, log: log)

    #expect(events == [childrenOrdered("p1", ["t2", "t1", "t3", "t4"], id: "id-1", lamport: 9)])
  }

  @Test("up swaps it with the one before")
  func movingUp() throws {
    let events = try makeCommands().moveChild(TaskID("t3"), by: -1, log: log)

    #expect(events == [childrenOrdered("p1", ["t1", "t3", "t2", "t4"], id: "id-1", lamport: 9)])
  }

  @Test("past either end writes nothing")
  func pastTheEndWritesNothing() throws {
    #expect(try makeCommands().moveChild(TaskID("t1"), by: -1, log: log) == [])
    #expect(try makeCommands().moveChild(TaskID("t4"), by: 1, log: log) == [])
  }

  @Test("an item filed in no project writes nothing")
  func looseItemWritesNothing() throws {
    let loose = log + [captured("x", "loose", lamport: 9)]

    #expect(try makeCommands().moveChild(TaskID("x"), by: 1, log: loose) == [])
  }

  @Test("an item that is not open is refused")
  func closedItemIsRefused() {
    let closed = log + [completed("t1", lamport: 9)]

    #expect(throws: CommandError.noOpenTask("t1")) {
      try makeCommands().moveChild(TaskID("t1"), by: 1, log: closed)
    }
  }
}
