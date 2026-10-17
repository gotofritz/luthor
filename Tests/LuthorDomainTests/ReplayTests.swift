import LuthorDomain
import LuthorTestSupport
import Testing

@Suite struct ReplayTests {
  @Test func capturedTaskIsOpenInInbox() {
    let state = LibraryState.replay([captured("t1", "buy milk")])

    #expect(state.view(.default).openTasks == [item("t1", "buy milk")])
  }

  @Test func completedTaskLeavesInbox() {
    let state = LibraryState.replay([
      captured("t1", "buy milk", lamport: 1),
      captured("t2", "call mum", lamport: 2),
      completed("t1", lamport: 3),
    ])

    #expect(state.view(.default).openTasks == [item("t2", "call mum")])
  }
}

@Suite struct ReplayOrderTests {
  static let log = [
    captured("t1", "buy milk", device: "mac", lamport: 1),
    captured("t2", "call mum", device: "mac", lamport: 2),
    captured("t3", "pay rent", device: "air", lamport: 2),
    completed("t1", device: "air", lamport: 3),
  ]

  static let arrivalOrders: [[Int]] = [
    [0, 1, 2, 3],
    [3, 2, 1, 0],
    [3, 0, 2, 1],
    [1, 3, 0, 2],
    [2, 0, 3, 1],
  ]

  @Test(arguments: arrivalOrders)
  func anyArrivalOrderReplaysToTheSameState(order: [Int]) {
    let state = LibraryState.replay(order.map { Self.log[$0] })

    // Same lamport: device ID breaks the tie, "air" before "mac".
    #expect(state.view(.default).openTasks == [item("t3", "pay rent"), item("t2", "call mum")])
  }

  @Test func duplicateEventsAreAppliedOnce() {
    let capture = captured("t1", "buy milk")

    let state = LibraryState.replay([capture, capture])

    #expect(state.view(.default).openTasks == [item("t1", "buy milk")])
  }
}
