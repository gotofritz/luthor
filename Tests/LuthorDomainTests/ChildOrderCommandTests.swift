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

private func ordered(_ sort: ChildSort, _ log: [EventEnvelope] = log) throws -> [String]? {
  let events = try makeCommands().sortChildren(of: TaskID("p1"), by: sort, log: log)
  guard case .childrenOrdered(let event)? = events.first?.payload else { return nil }
  return event.taskIDs.map(\.rawValue)
}

@Suite("When the children of a project are sorted by command")
struct SortChildrenCommandTests {
  @Test("by title, ignoring case, A to Z")
  func byTitleAscending() throws {
    #expect(try ordered(.title(ascending: true)) == ["t3", "t1", "t2", "t4"])
  }

  @Test("by title, Z to A")
  func byTitleDescending() throws {
    #expect(try ordered(.title(ascending: false)) == ["t4", "t2", "t1", "t3"])
  }

  @Test("by priority, A first, someday last, with no priority between, ties in the order they had")
  func byPriority() throws {
    #expect(try ordered(.priority) == ["t2", "t1", "t4", "t3"])
  }

  @Test("it writes one ChildrenOrdered after the highest Lamport in the log")
  func writesOneEvent() throws {
    let events = try makeCommands().sortChildren(of: TaskID("p1"), by: .priority, log: log)

    #expect(events.count == 1)
    #expect(events.first?.lamport == 9)
  }

  @Test("sorting what is in that order already writes nothing")
  func alreadySortedWritesNothing() throws {
    let sorted = log + [childrenOrdered("p1", ["t3", "t1", "t2", "t4"], lamport: 9)]

    #expect(try makeCommands().sortChildren(of: TaskID("p1"), by: .title(ascending: true), log: sorted) == [])
  }

  @Test("a project that does not exist is refused")
  func unknownProjectIsRefused() {
    #expect(throws: CommandError.unknownProject(TaskID("nope"))) {
      try makeCommands().sortChildren(of: TaskID("nope"), by: .priority, log: log)
    }
  }
}

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
