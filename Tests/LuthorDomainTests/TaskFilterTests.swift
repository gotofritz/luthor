import LuthorDomain
import LuthorTestSupport
import Testing

private let events = [
  captured("t1", "call bank", lamport: 1),
  captured("t2", "pay tax", lamport: 1),
  captured("t3", "write report", lamport: 1),
  captured("t4", "plan trip", lamport: 1),
  captured("t5", "other view task", view: "work", lamport: 1),
  viewCreated("work", "Work", lamport: 0),
  projectCreated("p1", "taxes", lamport: 1),
  projectCreated("p2", "filing", under: "p1", lamport: 2),
  moved("t2", to: "p1", lamport: 3),
  moved("t3", to: "p2", lamport: 3),
  tagCreated("calls", "calls", lamport: 1),
  tagCreated("home", "home", lamport: 1),
  tagged("t1", with: "calls", lamport: 2),
  tagged("t1", with: "home", lamport: 3),
  tagged("t2", with: "calls", lamport: 2),
  prioritized("t1", as: .critical, lamport: 2),
  prioritized("t2", as: .critical, lamport: 2),
  prioritized("t3", as: .important, lamport: 2),
  dueSet("t2", on: "2026-10-20", lamport: 2),
  dueSet("t3", on: "2026-10-30", hard: false, lamport: 2),
]

private func titles(_ filter: TaskFilter) -> [String] {
  LibraryState.replay(events).tasks(in: .default, matching: filter).map(\.title)
}

@Suite("When a view's tasks are filtered")
struct TaskFilterTests {
  @Test("no filter keeps every open task of the view, and nothing of another view")
  func noFilterKeepsEveryOpenTask() {
    #expect(titles(TaskFilter()) == ["call bank", "pay tax", "write report", "plan trip"])
    #expect(TaskFilter().isEmpty)
  }

  @Test("a tag keeps the tasks that carry it")
  func aTagKeepsTheTasksThatCarryIt() {
    #expect(titles(TaskFilter(tags: [TagID("calls")])) == ["call bank", "pay tax"])
  }

  @Test("several tags keep the tasks that carry all of them")
  func severalTagsKeepTheTasksThatCarryAllOfThem() {
    #expect(titles(TaskFilter(tags: [TagID("calls"), TagID("home")])) == ["call bank"])
  }

  @Test("a priority keeps the tasks that have it")
  func aPriorityKeepsTheTasksThatHaveIt() {
    #expect(titles(TaskFilter(priority: .critical)) == ["call bank", "pay tax"])
  }

  @Test("a project keeps its tasks and those of its sub-projects")
  func aProjectKeepsItsTasksAndThoseOfItsSubprojects() {
    #expect(titles(TaskFilter(projectID: TaskID("p1"))) == ["pay tax", "write report"])
    #expect(titles(TaskFilter(projectID: TaskID("p2"))) == ["write report"])
  }

  @Test("a deadline keeps the tasks due on that day or before, of either kind")
  func aDeadlineKeepsTheTasksDueByThatDay() {
    #expect(titles(TaskFilter(dueBy: date("2026-10-20"))) == ["pay tax"])
    #expect(titles(TaskFilter(dueBy: date("2026-10-31"))) == ["pay tax", "write report"])
  }

  @Test("filters combine: a task has to pass every one")
  func filtersCombine() {
    let filter = TaskFilter(tags: [TagID("calls")], priority: .critical, projectID: TaskID("p1"))

    #expect(titles(filter) == ["pay tax"])
    #expect(!filter.isEmpty)
  }

  @Test("a filter that nothing passes keeps nothing")
  func aFilterNothingPassesKeepsNothing() {
    #expect(titles(TaskFilter(tags: [TagID("home")], priority: .important)).isEmpty)
  }
}

@Suite("When Today's candidates are filtered")
struct CandidateFilterTests {
  private let state = LibraryState.replay(events)

  private func candidates(_ filter: TaskFilter) -> [String] {
    state.plan(for: .default, on: date("2026-10-19"), today: date("2026-10-19"), matching: filter)
      .candidates.map(\.task.title)
  }

  @Test("without a filter the plan is as it was")
  func withoutAFilterThePlanIsAsItWas() {
    #expect(candidates(TaskFilter()) == ["pay tax", "call bank", "write report"])
  }

  @Test("a tag keeps the candidates that carry it, in the suggested order")
  func aTagKeepsTheCandidatesThatCarryIt() {
    #expect(candidates(TaskFilter(tags: [TagID("calls")])) == ["pay tax", "call bank"])
  }

  @Test("a priority, a project and a deadline filter the candidates too")
  func aPriorityAProjectAndADeadlineFilterToo() {
    #expect(candidates(TaskFilter(priority: .important)) == ["write report"])
    #expect(candidates(TaskFilter(projectID: TaskID("p1"))) == ["pay tax", "write report"])
    #expect(candidates(TaskFilter(dueBy: date("2026-10-20"))) == ["pay tax"])
  }

  @Test("the tasks planned for the day stay in the plan, whatever the filter")
  func thePlannedTasksStayInThePlan() {
    let planned = LibraryState.replay(events + [scheduled("t1", on: "2026-10-19", lamport: 4)])

    let plan = planned.plan(
      for: .default, on: date("2026-10-19"), today: date("2026-10-19"), matching: TaskFilter(tags: [TagID("ghost")]))

    #expect(plan.entries.map(\.task.title) == ["call bank"])
    #expect(plan.candidates.isEmpty)
  }
}
