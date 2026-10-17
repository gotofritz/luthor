import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When a task is clarified")
struct InboxClarifyTests {
  @Test("an unclarified task stays in the inbox")
  func unclarifiedTaskStaysInTheInbox() {
    let state = LibraryState.replay([captured("t1", "buy milk", lamport: 1)])

    #expect(state.view(.default).inbox == [item("t1", "buy milk")])
  }

  @Test("a priority clarifies a task, and it leaves the inbox")
  func priorityClarifiesTheTask() {
    let state = LibraryState.replay([
      captured("t1", "buy milk", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
    ])

    #expect(state.view(.default).inbox == [])
    #expect(state.view(.default).openTasks == [item("t1", "buy milk", priority: .critical)])
  }

  @Test("an estimate clarifies a task, and it leaves the inbox")
  func estimateClarifiesTheTask() {
    let state = LibraryState.replay([captured("t1", "buy milk", lamport: 1), estimated("t1", as: 15, lamport: 2)])

    #expect(state.view(.default).inbox == [])
    #expect(state.view(.default).openTasks == [item("t1", "buy milk", estimate: 15)])
  }

  @Test("filing into a project clarifies a task, and it leaves the inbox")
  func filingClarifiesTheTask() {
    let state = LibraryState.replay([
      captured("t1", "buy milk", lamport: 1),
      projectCreated("p1", "Errands", lamport: 2),
      moved("t1", to: "p1", lamport: 3),
    ])

    #expect(state.view(.default).inbox == [])
  }

  @Test("clearing both a priority and an estimate returns an unfiled task to the inbox")
  func clearingBothReturnsItToTheInbox() {
    let state = LibraryState.replay([
      captured("t1", "buy milk", lamport: 1),
      prioritized("t1", as: .critical, lamport: 2),
      estimated("t1", as: 15, lamport: 3),
      prioritized("t1", as: nil, lamport: 4),
      estimated("t1", as: nil, lamport: 5),
    ])

    #expect(state.view(.default).inbox == [item("t1", "buy milk")])
  }
}

@Suite("When a task is marked someday")
struct SomedayNextActionTests {
  @Test("it is never a next action of its project")
  func somedayTaskIsNeverANextAction() {
    let state = LibraryState.replay([
      captured("t1", "research movers", lamport: 1),
      projectCreated("p1", "Move house", kind: .parallel, lamport: 2),
      moved("t1", to: "p1", lamport: 3),
      prioritized("t1", as: .someday, lamport: 4),
    ])

    #expect(state.view(.default).nextActions(of: ProjectID("p1")) == [])
    #expect(state.view(.default).nextActions == [])
  }

  @Test("promoting it to another priority makes it a next action again")
  func promotingMakesItANextActionAgain() {
    let state = LibraryState.replay([
      captured("t1", "research movers", lamport: 1),
      projectCreated("p1", "Move house", kind: .parallel, lamport: 2),
      moved("t1", to: "p1", lamport: 3),
      prioritized("t1", as: .someday, lamport: 4),
      prioritized("t1", as: .optional, lamport: 5),
    ])

    #expect(state.view(.default).nextActions.map(\.id.rawValue) == ["t1"])
  }
}
