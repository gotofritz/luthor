import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When a task is prioritised")
struct PriorityReplayTests {
  static let base = [
    captured("t1", "pay rent", lamport: 1),
    captured("t2", "call mum", lamport: 2),
  ]

  @Test("the task carries the priority, and leaves the inbox: it is clarified now")
  func prioritisedTaskCarriesIt() {
    let state = LibraryState.replay(Self.base + [prioritized("t1", as: .critical, lamport: 3)])

    #expect(
      state.view(.default).openTasks == [item("t1", "pay rent", priority: .critical), item("t2", "call mum")])
    #expect(state.view(.default).inbox == [item("t2", "call mum")])
  }

  @Test("the last priority wins")
  func lastPriorityWins() {
    let state = LibraryState.replay(
      Self.base + [prioritized("t1", as: .critical, lamport: 3), prioritized("t1", as: .optional, lamport: 4)])

    #expect(state.view(.default).openTasks.first?.priority == .optional)
  }

  @Test("clearing it leaves the task without a priority")
  func clearingRemovesThePriority() {
    let state = LibraryState.replay(
      Self.base + [prioritized("t1", as: .critical, lamport: 3), prioritized("t1", as: nil, lamport: 4)])

    #expect(state.view(.default).inbox.first?.priority == nil)
  }

  @Test("a task that is not open is ignored")
  func unknownTaskIsIgnored() {
    let state = LibraryState.replay(Self.base + [prioritized("t9", as: .critical, lamport: 3)])

    #expect(state.view(.default).inbox == [item("t1", "pay rent"), item("t2", "call mum")])
  }

  @Test("the priority survives filing the task into a project")
  func priorityIsKeptWhenFiled() {
    let state = LibraryState.replay(
      Self.base + [
        projectCreated("p1", "Move house", lamport: 3),
        prioritized("t1", as: .important, lamport: 4),
        moved("t1", to: "p1", lamport: 5),
      ])

    let filed = item("t1", "pay rent", in: "p1", priority: .important)
    #expect(state.view(.default).projects.first?.tasks == [filed])
    #expect(state.view(.default).openTasks.first == filed)
  }

  @Test("the priority survives taking the task to another view")
  func priorityIsKeptAcrossViews() {
    let state = LibraryState.replay(
      Self.base + [
        viewCreated("v1", "Work", lamport: 3),
        prioritized("t1", as: .important, lamport: 4),
        movedToView("t1", toView: "v1", lamport: 5),
      ])

    #expect(state.view(ViewID("v1")).openTasks == [item("t1", "pay rent", view: "v1", priority: .important)])
    #expect(state.view(ViewID("v1")).inbox == [])
  }

  @Test("the priority of a task in a project survives taking the project to another view")
  func priorityIsKeptWhenTheProjectMoves() {
    let state = LibraryState.replay(
      Self.base + [
        projectCreated("p1", "Move house", lamport: 3),
        moved("t1", to: "p1", lamport: 4),
        prioritized("t1", as: .someday, lamport: 5),
        viewCreated("v1", "Work", lamport: 6),
        projectMovedToView("p1", toView: "v1", lamport: 7),
      ])

    #expect(
      state.view(ViewID("v1")).openTasks == [item("t1", "pay rent", in: "p1", view: "v1", priority: .someday)])
  }
}

@Suite("When tasks are listed by priority")
struct TasksByPriorityTests {
  static let state = LibraryState.replay([
    captured("t1", "someday thing", lamport: 1),
    captured("t2", "critical thing", lamport: 2),
    captured("t3", "unranked", lamport: 3),
    captured("t4", "another critical", lamport: 4),
    captured("t5", "important", lamport: 5),
    prioritized("t1", as: .someday, lamport: 6),
    prioritized("t2", as: .critical, lamport: 7),
    prioritized("t4", as: .critical, lamport: 8),
    prioritized("t5", as: .important, lamport: 9),
  ])

  @Test("no priority selected lists nothing")
  func noPriorityListsNothing() {
    #expect(Self.state.view(.default).tasks(prioritised: []) == [])
  }

  @Test("one priority lists its tasks in capture order")
  func onePriorityListsItsTasks() {
    let tasks = Self.state.view(.default).tasks(prioritised: [.critical])

    #expect(tasks.map(\.id.rawValue) == ["t2", "t4"])
  }

  @Test("several priorities list the most urgent first, then in capture order")
  func severalPrioritiesAreOrderedByUrgency() {
    let tasks = Self.state.view(.default).tasks(prioritised: [.someday, .important, .critical])

    #expect(tasks.map(\.id.rawValue) == ["t2", "t4", "t5", "t1"])
  }

  @Test("a task of another view is never listed")
  func otherViewsAreNotListed() {
    let state = LibraryState.replay([
      viewCreated("v1", "Work", lamport: 1),
      captured("t1", "work thing", view: "v1", lamport: 2),
      prioritized("t1", as: .critical, lamport: 3),
    ])

    #expect(state.view(.default).tasks(prioritised: [.critical]) == [])
  }
}
