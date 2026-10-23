import LuthorDomain
import LuthorTestSupport
import Testing

private let monday = date("2026-10-19")

/// "File taxes" holds two B tasks; "Water plants" is a B task of its own, captured last.
private let taxes = [
  projectCreated("p1", "File taxes", lamport: 1),
  captured("t1", "gather receipts", under: "p1", lamport: 2), prioritized("t1", as: .important, lamport: 3),
  captured("t2", "fill the form", under: "p1", lamport: 4), prioritized("t2", as: .important, lamport: 5),
  captured("t3", "water plants", lamport: 6), prioritized("t3", as: .important, lamport: 7),
]

@Suite("When a project has a due date")
struct EffectiveDueDateTests {
  @Test("a task in it with none of its own is due when the project is, as set there")
  func theTaskInheritsIt() {
    let state = LibraryState.replay(taxes + [dueSet("p1", on: "2026-10-23", hard: false, lamport: 8)])

    #expect(state.effectiveDueDate(of: TaskID("t1")) == DueDate(date: date("2026-10-23"), isHard: false))
  }

  @Test("a task with its own keeps it")
  func theTaskKeepsItsOwn() {
    let events = taxes + [dueSet("p1", on: "2026-10-23", lamport: 8), dueSet("t1", on: "2026-10-21", lamport: 9)]

    #expect(LibraryState.replay(events).effectiveDueDate(of: TaskID("t1"))?.date == date("2026-10-21"))
  }

  @Test("the nearest project with one decides, at any depth")
  func theNearestProjectDecides() {
    let events =
      taxes + [
        projectCreated("p2", "Forms", under: "p1", lamport: 8),
        captured("t4", "sign", under: "p2", lamport: 9),
        dueSet("p1", on: "2026-10-30", lamport: 10), dueSet("p2", on: "2026-10-25", lamport: 11),
      ]

    #expect(LibraryState.replay(events).effectiveDueDate(of: TaskID("t4"))?.date == date("2026-10-25"))
  }

  @Test("a task outside it, or in a project with none, has no due date")
  func otherTasksHaveNone() {
    let state = LibraryState.replay(taxes + [dueSet("p1", on: "2026-10-23", lamport: 8)])

    #expect(state.effectiveDueDate(of: TaskID("t3")) == nil)
  }

  @Test("a hard deadline that is due ranks its tasks ahead of their priority peers")
  func theDeadlineRanksItsTasks() {
    let state = LibraryState.replay(taxes + [dueSet("p1", on: "2026-10-19", lamport: 8)])

    let candidates = state.plan(for: .default, on: monday, today: monday).candidates

    #expect(candidates.map(\.task.title) == ["gather receipts", "fill the form", "water plants"])
  }

  @Test("a target date ranks its tasks too")
  func aTargetDateRanksItsTasks() {
    let state = LibraryState.replay(taxes + [dueSet("p1", on: "2026-10-19", hard: false, lamport: 8)])

    let candidates = state.plan(for: .default, on: monday, today: monday).candidates

    #expect(candidates.map(\.task.title) == ["gather receipts", "fill the form", "water plants"])
  }
}

@Suite("When the plan and the calendar meet a project")
struct ContainerPlanningTests {
  @Test("only its tasks are candidates, never the project itself")
  func onlyLeavesAreCandidates() {
    let state = LibraryState.replay(taxes + [prioritized("p1", as: .critical, lamport: 8)])

    let candidates = state.plan(for: .default, on: monday, today: monday).candidates

    #expect(!candidates.map(\.task.id).contains(TaskID("p1")))
  }

  @Test("its own estimate is not planned, only the estimates of its tasks")
  func theOwnEstimateIsNotPlanned() {
    let events = taxes + [estimated("p1", as: 600, lamport: 8), scheduled("t1", on: "2026-10-19", lamport: 9)]

    let plan = LibraryState.replay(events).plan(for: .default, on: monday, today: monday)

    #expect(plan.entries.map(\.task.id) == [TaskID("t1")])
    #expect(plan.capacity.plannedMinutes == plan.entries.first?.minutes)
  }

  @Test("a due date on the project is marked on the calendar on that day, once")
  func theCalendarMarksTheProject() {
    let state = LibraryState.replay(taxes + [dueSet("p1", on: "2026-10-23", lamport: 8)])

    let days = state.calendar(for: .default, from: monday, days: 7)

    #expect(days.first { $0.date == date("2026-10-23") }?.dueCount == 1)
  }

  @Test("the day lists the project that is due, and not its tasks")
  func theDayListsTheProject() {
    let state = LibraryState.replay(taxes + [dueSet("p1", on: "2026-10-23", lamport: 8)])

    let entries = state.calendarEntries(for: .default, on: date("2026-10-23"), today: monday)

    #expect(entries.map(\.task.id) == [TaskID("p1")])
  }
}

@Suite("When a project has estimates among its tasks")
struct RolledUpEstimateTests {
  static let withEstimates =
    taxes + [estimated("t1", as: 30, lamport: 8), estimated("t2", as: 45, lamport: 9)]

  @Test("it shows the sum of its open tasks' estimates")
  func itSumsTheOpenTasks() {
    #expect(LibraryState.replay(Self.withEstimates).rolledUpEstimate(of: TaskID("p1")) == 75)
  }

  @Test("tasks in sub-projects count, and a completed task does not")
  func subProjectsCountAndCompletedTasksDoNot() {
    let events =
      Self.withEstimates + [
        projectCreated("p2", "Forms", under: "p1", lamport: 10),
        captured("t4", "sign", under: "p2", lamport: 11), estimated("t4", as: 15, lamport: 12),
        completed("t1", lamport: 13),
      ]

    #expect(LibraryState.replay(events).rolledUpEstimate(of: TaskID("p1")) == 60)
  }

  @Test("its own estimate wins, never added to theirs")
  func theOwnEstimateWins() {
    let events = Self.withEstimates + [estimated("p1", as: 600, lamport: 10)]

    #expect(LibraryState.replay(events).rolledUpEstimate(of: TaskID("p1")) == 600)
  }

  @Test("with no estimate anywhere there is none")
  func noEstimateAnywhere() {
    #expect(LibraryState.replay(taxes).rolledUpEstimate(of: TaskID("p1")) == nil)
  }
}
