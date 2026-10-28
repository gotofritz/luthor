import LuthorDomain
import LuthorTestSupport
import Testing

private func step(after log: [EventEnvelope], _ events: [EventEnvelope]) -> UndoStep? {
  LibraryState.replay(log).undoStep(for: events.map(\.payload))
}

private let base = [captured("t1", "call bank", lamport: 1)]

@Suite("When a command is taken back")
struct UndoStepTests {
  @Test("completing a task is undone by reopening it")
  func completionIsUndoneByReopening() {
    let undo = step(after: base, [completed("t1")])

    #expect(undo?.backward == [reopened("t1").payload])
    #expect(undo?.forward == [completed("t1").payload])
  }

  @Test("dropping a task planned for a day puts it back on that day")
  func droppingIsUndoneWithItsDay() {
    let log = base + [scheduled("t1", on: "2026-10-20")]

    #expect(
      step(after: log, [dropped("t1")])?.backward == [
        reopened("t1").payload, scheduled("t1", on: "2026-10-20").payload,
      ])
  }

  @Test("a priority is put back to the one before, or none")
  func priorityIsPutBack() {
    let log = base + [prioritized("t1", as: .important)]

    #expect(step(after: log, [prioritized("t1", as: .someday)])?.backward == [prioritized("t1", as: .important).payload])
    #expect(step(after: base, [prioritized("t1", as: .critical)])?.backward == [prioritized("t1", as: nil).payload])
  }

  @Test("an estimate is put back to the one before")
  func estimateIsPutBack() {
    let log = base + [estimated("t1", as: 15)]

    #expect(step(after: log, [estimated("t1", as: 60)])?.backward == [estimated("t1", as: 15).payload])
  }

  @Test("a task planned for a day is put back on its day, or off any day")
  func scheduleIsPutBack() {
    let planned = base + [scheduled("t1", on: "2026-10-20")]

    #expect(step(after: planned, [scheduled("t1", on: "2026-10-21")])?.backward == [scheduled("t1", on: "2026-10-20").payload])
    #expect(step(after: base, [scheduled("t1", on: "2026-10-21")])?.backward == [unscheduled("t1").payload])
    #expect(step(after: planned, [unscheduled("t1")])?.backward == [scheduled("t1", on: "2026-10-20").payload])
  }

  @Test("sending a task to someday is undone in reverse order, restoring both its day and priority")
  func severalEventsAreUndoneInReverse() {
    let log = base + [prioritized("t1", as: .critical), scheduled("t1", on: "2026-10-20")]
    let events = [unscheduled("t1"), prioritized("t1", as: .someday)]

    #expect(
      step(after: log, events)?.backward == [
        prioritized("t1", as: .critical).payload, scheduled("t1", on: "2026-10-20").payload,
      ])
  }

  @Test("a move is put back under the project it was in")
  func moveIsPutBack() {
    let unfiled = EventEnvelope(
      id: EventID("unfile"), deviceID: DeviceID("mac"), lamport: 4,
      payload: .taskMoved(TaskMoved(taskID: TaskID("t1"), parentID: nil)))
    let log = [projectCreated("p1", "Trip", lamport: 1), captured("t1", "flights", lamport: 2), moved("t1", to: "p1", lamport: 3)]

    #expect(step(after: log, [unfiled])?.backward == [moved("t1", to: "p1").payload])
  }

  @Test("a due date and a title are put back")
  func dueDateAndTitleArePutBack() {
    let log = base + [dueSet("t1", on: "2026-11-01", hard: true)]

    #expect(
      step(after: log, [dueSet("t1", on: "2026-12-01", hard: false)])?.backward == [
        dueSet("t1", on: "2026-11-01", hard: true).payload
      ])
    #expect(step(after: base, [renamed("t1", to: "ring bank")])?.backward == [renamed("t1", to: "call bank").payload])
  }

  @Test("tagging is undone by untagging and untagging by tagging")
  func taggingIsUndone() {
    let log = base + [tagCreated("g1", "home"), tagged("t1", "g1")]

    #expect(step(after: base + [tagCreated("g1", "home")], [tagged("t1", "g1")])?.backward == [untagged("t1", "g1").payload])
    #expect(step(after: log, [untagged("t1", "g1")])?.backward == [tagged("t1", "g1").payload])
  }

  @Test("a task captured cannot be taken back, so the command is not undoable")
  func capturingIsNotUndoable() {
    #expect(step(after: [], [captured("t2", "new")]) == nil)
  }
}
