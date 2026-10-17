import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When a task is estimated")
struct EstimateReplayTests {
  static let base = [
    captured("t1", "pay rent", lamport: 1),
    captured("t2", "call mum", lamport: 2),
  ]

  @Test("the task carries the estimate")
  func estimatedTaskCarriesIt() {
    let state = LibraryState.replay(Self.base + [estimated("t1", as: 15, lamport: 3)])

    #expect(state.view(.default).openTasks == [item("t1", "pay rent", estimate: 15), item("t2", "call mum")])
  }

  @Test("the last estimate wins")
  func lastEstimateWins() {
    let state = LibraryState.replay(
      Self.base + [estimated("t1", as: 15, lamport: 3), estimated("t1", as: 30, lamport: 4)])

    #expect(state.view(.default).openTasks.first?.estimate == 30)
  }

  @Test("clearing it leaves the task without an estimate")
  func clearingRemovesTheEstimate() {
    let state = LibraryState.replay(
      Self.base + [estimated("t1", as: 15, lamport: 3), estimated("t1", as: nil, lamport: 4)])

    #expect(state.view(.default).openTasks.first?.estimate == nil)
  }

  @Test("a task that is not open is ignored")
  func unknownTaskIsIgnored() {
    let state = LibraryState.replay(Self.base + [estimated("t9", as: 15, lamport: 3)])

    #expect(state.view(.default).openTasks == [item("t1", "pay rent"), item("t2", "call mum")])
  }

  @Test("the estimate survives filing the task into a project")
  func estimateIsKeptWhenFiled() {
    let state = LibraryState.replay(
      Self.base + [
        projectCreated("p1", "Move house", lamport: 3),
        estimated("t1", as: 15, lamport: 4),
        moved("t1", to: "p1", lamport: 5),
      ])

    let filed = item("t1", "pay rent", in: "p1", estimate: 15)
    #expect(state.view(.default).projects.first?.tasks == [filed])
    #expect(state.view(.default).openTasks.first == filed)
  }

  @Test("the estimate survives taking the task to another view")
  func estimateIsKeptAcrossViews() {
    let state = LibraryState.replay(
      Self.base + [
        viewCreated("v1", "Work", lamport: 3),
        estimated("t1", as: 15, lamport: 4),
        movedToView("t1", toView: "v1", lamport: 5),
      ])

    #expect(state.view(ViewID("v1")).openTasks == [item("t1", "pay rent", view: "v1", estimate: 15)])
  }

  @Test("the estimate of a task in a project survives taking the project to another view")
  func estimateIsKeptWhenTheProjectMoves() {
    let state = LibraryState.replay(
      Self.base + [
        projectCreated("p1", "Move house", lamport: 3),
        moved("t1", to: "p1", lamport: 4),
        estimated("t1", as: 30, lamport: 5),
        viewCreated("v1", "Work", lamport: 6),
        projectMovedToView("p1", toView: "v1", lamport: 7),
      ])

    #expect(state.view(ViewID("v1")).openTasks == [item("t1", "pay rent", in: "p1", view: "v1", estimate: 30)])
  }
}
