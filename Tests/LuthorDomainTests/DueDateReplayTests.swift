import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When a task is given a due date")
struct DueDateReplayTests {
  static let base = [captured("t1", "pay tax", lamport: 1)]

  @Test("it has a hard deadline on that day")
  func itHasAHardDeadlineOnThatDay() {
    let state = LibraryState.replay(Self.base + [dueSet("t1", on: "2026-10-23", lamport: 2)])

    #expect(state.dueDate(of: TaskID("t1")) == DueDate(date: date("2026-10-23"), isHard: true))
  }

  @Test("it can be a target date instead")
  func itCanBeATargetDateInstead() {
    let state = LibraryState.replay(Self.base + [dueSet("t1", on: "2026-10-23", hard: false, lamport: 2)])

    #expect(state.dueDate(of: TaskID("t1")) == DueDate(date: date("2026-10-23"), isHard: false))
  }

  @Test("a task with none has no due date")
  func aTaskWithNoneHasNoDueDate() {
    #expect(LibraryState.replay(Self.base).dueDate(of: TaskID("t1")) == nil)
  }

  @Test("setting it again replaces it, and the task stays one task")
  func settingItAgainReplacesIt() {
    let state = LibraryState.replay(
      Self.base + [dueSet("t1", on: "2026-10-23", lamport: 2), dueSet("t1", on: "2026-10-30", hard: false, lamport: 3)])

    #expect(state.dueDate(of: TaskID("t1")) == DueDate(date: date("2026-10-30"), isHard: false))
    #expect(state.view(.default).openTasks == [item("t1", "pay tax")])
  }

  @Test("clearing it removes it")
  func clearingItRemovesIt() {
    let state = LibraryState.replay(
      Self.base + [dueSet("t1", on: "2026-10-23", lamport: 2), dueSet("t1", on: nil, lamport: 3)])

    #expect(state.dueDate(of: TaskID("t1")) == nil)
  }

  @Test("a task that is not open is ignored")
  func aTaskThatIsNotOpenIsIgnored() {
    let state = LibraryState.replay([dueSet("t9", on: "2026-10-23", lamport: 1)])

    #expect(state.dueDate(of: TaskID("t9")) == nil)
  }

  @Test("it never plans the task for a day")
  func itNeverPlansTheTaskForADay() {
    let state = LibraryState.replay(Self.base + [dueSet("t1", on: "2026-10-23", lamport: 2)])

    #expect(state.scheduledDate(of: TaskID("t1")) == nil)
  }

  @Test("a completed task is no longer open, and reopening it brings its due date back")
  func reopeningBringsTheDueDateBack() {
    let events = Self.base + [dueSet("t1", on: "2026-10-23", lamport: 2), completed("t1", lamport: 3)]
    let done = LibraryState.replay(events)
    let reopenedState = LibraryState.replay(events + [reopened("t1", lamport: 4)])

    #expect(done.view(.default).openTasks.isEmpty)
    #expect(reopenedState.dueDate(of: TaskID("t1")) == DueDate(date: date("2026-10-23"), isHard: true))
  }

  @Test("the same events in any arrival order give the same state")
  func theSameEventsInAnyArrivalOrderGiveTheSameState() {
    let events =
      Self.base + [
        dueSet("t1", on: "2026-10-23", lamport: 2), dueSet("t1", on: "2026-10-30", hard: false, lamport: 3),
      ]

    #expect(LibraryState.replay(events) == LibraryState.replay(events.reversed()))
  }
}
