import LuthorDomain
import LuthorTestSupport
import Testing

private let steps = [
  projectCreated("p1", "Move house", kind: .sequential, lamport: 1),
  captured("t1", "pack", under: "p1", lamport: 2),
  captured("t2", "hire van", under: "p1", lamport: 3),
  captured("t3", "move", under: "p1", lamport: 4),
]

private func childIDs(_ log: [EventEnvelope], of project: String = "p1") -> [TaskID] {
  LibraryState.replay(log).view(.default).projects.first { $0.id == TaskID(project) }?.tasks.map(\.id) ?? []
}

@Suite("When the children of a project are put in order")
struct ChildOrderReplayTests {
  @Test("they are listed in the order given")
  func listedInTheOrderGiven() {
    let log = steps + [childrenOrdered("p1", ["t3", "t1", "t2"])]

    #expect(childIDs(log) == [TaskID("t3"), TaskID("t1"), TaskID("t2")])
  }

  @Test("a child left out keeps its place after those named")
  func leftOutChildrenFollow() {
    let log = steps + [childrenOrdered("p1", ["t3"])]

    #expect(childIDs(log) == [TaskID("t3"), TaskID("t1"), TaskID("t2")])
  }

  @Test("an item that is not a child is ignored, and a child named twice counts once")
  func strangersAndRepeatsAreIgnored() {
    let log = steps + [captured("x", "elsewhere", lamport: 5), childrenOrdered("p1", ["x", "t2", "t2", "t1"])]

    #expect(childIDs(log) == [TaskID("t2"), TaskID("t1"), TaskID("t3")])
  }

  @Test("a child added afterwards goes to the end")
  func laterChildGoesLast() {
    let log = steps + [childrenOrdered("p1", ["t3", "t2", "t1"]), captured("t4", "unpack", under: "p1", lamport: 10)]

    #expect(childIDs(log) == [TaskID("t3"), TaskID("t2"), TaskID("t1"), TaskID("t4")])
  }

  @Test("the first open child of a sequential project is the next action in the new order")
  func nextActionFollowsTheOrder() {
    let log = steps + [childrenOrdered("p1", ["t2", "t1", "t3"])]

    #expect(LibraryState.replay(log).view(.default).nextActions(of: TaskID("p1")).map(\.id) == [TaskID("t2")])
  }

  @Test("two orderings arriving in either order give the same list")
  func arrivalOrderDoesNotMatter() {
    let first = childrenOrdered("p1", ["t2", "t1", "t3"], id: "a", device: "mac", lamport: 8)
    let second = childrenOrdered("p1", ["t3", "t2", "t1"], id: "b", device: "phone", lamport: 9)

    #expect(childIDs(steps + [first, second]) == childIDs(steps + [second, first]))
    #expect(childIDs(steps + [second, first]) == [TaskID("t3"), TaskID("t2"), TaskID("t1")])
  }

  @Test("a reopened child goes to the end, as before")
  func reopenedChildGoesLast() {
    let log =
      steps + [
        childrenOrdered("p1", ["t3", "t2", "t1"], lamport: 5), completed("t2", lamport: 6),
        reopened("t2", lamport: 7),
      ]

    #expect(childIDs(log) == [TaskID("t3"), TaskID("t1"), TaskID("t2")])
  }

  @Test("a copy of the project keeps the order of the source")
  func copyKeepsTheOrder() {
    let log = steps + [childrenOrdered("p1", ["t3", "t1", "t2"]), duplicated("p1", as: "c1", lamport: 10)]
    let copies = LibraryState.replay(log).view(.default).projects.first { $0.id == TaskID("c1") }

    #expect(copies?.tasks.map(\.title) == ["move", "pack", "hire van"])
  }
}
