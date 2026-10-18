import LuthorDomain
import LuthorTestSupport
import Testing

private let weekly = RepeatRule(every: 1, unit: .week)
private let monday = "2026-10-19"
private let nextMonday = "2026-10-26"

/// A weekly task in a project, with a priority, an estimate, notes, a tag, a hard deadline, a day it is planned
/// for and a delegation: everything the next one does or does not copy.
private let routine: [EventEnvelope] = [
  projectCreated("p1", "Home", lamport: 1),
  captured("t1", "water plants", lamport: 1),
  moved("t1", to: "p1", lamport: 2),
  prioritized("t1", as: .important, lamport: 2),
  estimated("t1", as: 15, lamport: 2),
  noted("t1", "front room first", lamport: 2),
  tagCreated("g1", "home", lamport: 2),
  tagged("t1", with: "g1", lamport: 3),
  dueSet("t1", on: monday, lamport: 3),
  repeatSet("t1", weekly, lamport: 3),
  scheduled("t1", on: monday, lamport: 3),
  delegated("t1", to: "Sam", lamport: 4),
]

@Suite("When a task is given a repeat")
struct RepeatSetReplayTests {
  @Test("the task has the rule, and clearing it takes it away")
  func theTaskHasTheRule() {
    let base = [captured("t1", "water plants", lamport: 1)]

    let set = LibraryState.replay(base + [repeatSet("t1", weekly, lamport: 2)])
    let cleared = LibraryState.replay(base + [repeatSet("t1", weekly, lamport: 2), repeatSet("t1", nil, lamport: 3)])

    #expect(set.repeatRule(of: TaskID("t1")) == weekly)
    #expect(cleared.repeatRule(of: TaskID("t1")) == nil)
  }

  @Test("setting it again replaces the rule")
  func settingItAgainReplacesTheRule() {
    let daily = RepeatRule(every: 1, unit: .day)
    let state = LibraryState.replay([
      captured("t1", "water plants", lamport: 1), repeatSet("t1", weekly, lamport: 2),
      repeatSet("t1", daily, lamport: 3),
    ])

    #expect(state.repeatRule(of: TaskID("t1")) == daily)
  }

  @Test("a task that is not open is ignored")
  func aTaskThatIsNotOpenIsIgnored() {
    let state = LibraryState.replay([
      captured("t1", "water plants", lamport: 1), completed("t1", lamport: 2), repeatSet("t1", weekly, lamport: 3),
      repeatSet("ghost", weekly, lamport: 3),
    ])

    #expect(state.repeatRule(of: TaskID("t1")) == nil)
    #expect(state.repeatRule(of: TaskID("ghost")) == nil)
  }
}

@Suite("When a repeating task recurs")
struct RecurrenceReplayTests {
  static let done = routine + [completed("t1", lamport: 5), recurred("t1", as: "t2", due: nextMonday, lamport: 6)]

  @Test("the next task is a copy of the one before, in its project, with the new due date")
  func theNextTaskIsACopy() {
    let state = LibraryState.replay(Self.done)

    let open = state.view(.default).openTasks
    #expect(
      open == [item("t2", "water plants", in: "p1", priority: .important, estimate: 15, notes: "front room first")])
    #expect(state.view(.default).projects.first?.children == [.task(open[0])])
    #expect(state.dueDate(of: TaskID("t2")) == DueDate(date: date(nextMonday), isHard: true))
  }

  @Test("it keeps the kind of the due date, and the tags and the rule")
  func itKeepsTheKindTheTagsAndTheRule() {
    let events =
      routine + [
        dueSet("t1", on: monday, hard: false, lamport: 4), completed("t1", lamport: 5),
        recurred("t1", as: "t2", due: nextMonday, lamport: 6),
      ]

    let state = LibraryState.replay(events)

    #expect(state.dueDate(of: TaskID("t2")) == DueDate(date: date(nextMonday), isHard: false))
    #expect(state.tags(of: TaskID("t2")).map(\.name) == ["home"])
    #expect(state.repeatRule(of: TaskID("t2")) == weekly)
  }

  @Test("it does not copy the day it was planned for or the delegation")
  func itDoesNotCopyThePlanOrTheDelegation() {
    let state = LibraryState.replay(Self.done)

    #expect(state.scheduledDate(of: TaskID("t2")) == nil)
    #expect(state.delegation(of: TaskID("t2")) == nil)
  }

  @Test("the completed task stays in Completed")
  func theCompletedTaskStaysInCompleted() {
    let state = LibraryState.replay(Self.done)

    #expect(state.view(.default).completedTasks.map(\.item.id) == [TaskID("t1")])
  }

  @Test("editing the open task changes what the next ones copy")
  func editingTheOpenTaskChangesWhatTheNextOnesCopy() {
    let events =
      routine + [
        renamed("t1", to: "water the ferns", lamport: 4), completed("t1", lamport: 5),
        recurred("t1", as: "t2", due: nextMonday, lamport: 6),
      ]

    let state = LibraryState.replay(events)

    #expect(state.view(.default).openTasks.map(\.title) == ["water the ferns"])
  }

  @Test("a second device writing the same next task is ignored, and the first one in replay order wins")
  func aSecondDeviceWritingTheSameNextTaskIsIgnored() {
    let events =
      routine + [
        completed("t1", lamport: 5),
        recurred("t1", as: "t2", due: nextMonday, id: "recur-mac", device: "mac", lamport: 6),
        recurred("t1", as: "t2", due: "2026-10-27", id: "recur-phone", device: "phone", lamport: 6),
      ]

    let state = LibraryState.replay(events)

    #expect(state.view(.default).openTasks.map(\.id) == [TaskID("t2")])
    #expect(state.dueDate(of: TaskID("t2"))?.date == date(nextMonday))
  }

  @Test("the same event twice applies once")
  func theSameEventTwiceAppliesOnce() throws {
    let once = LibraryState.replay(Self.done)
    let twice = LibraryState.replay(Self.done + [try #require(Self.done.last)])

    #expect(twice == once)
  }

  @Test("any arrival order gives the same state")
  func anyArrivalOrderGivesTheSameState() {
    let expected = LibraryState.replay(Self.done)
    var generator = SeededGenerator(seed: 7)

    #expect(LibraryState.replay(Self.done.reversed()) == expected)
    #expect(LibraryState.replay(Self.done.shuffled(using: &generator)) == expected)
  }

  @Test("a task that is unknown recurs into nothing")
  func aTaskThatIsUnknownRecursIntoNothing() {
    let state = LibraryState.replay([recurred("ghost", as: "t2", due: nextMonday, lamport: 1)])

    #expect(state.view(.default).openTasks.isEmpty)
  }

  @Test("skipping drops the task, keeps it with the dropped items and leaves the next one")
  func skippingDropsTheTaskAndLeavesTheNextOne() {
    let events = routine + [recurred("t1", as: "t2", due: nextMonday, lamport: 5), dropped("t1", lamport: 6)]

    let state = LibraryState.replay(events)

    #expect(state.view(.default).openTasks.map(\.id) == [TaskID("t2")])
    #expect(state.view(.default).completedTasks.map(\.item.id) == [TaskID("t1")])
    #expect(state.view(.default).completedTasks.first?.isDropped == true)
  }

  @Test("reopening the completed task leaves the next one as it is")
  func reopeningTheCompletedTaskLeavesTheNextOneAsItIs() {
    let state = LibraryState.replay(Self.done + [reopened("t1", lamport: 7)])

    #expect(state.view(.default).openTasks.map(\.id) == [TaskID("t1"), TaskID("t2")])
    #expect(state.dueDate(of: TaskID("t2"))?.date == date(nextMonday))
  }

  @Test("completing the reopened task again does not make a second next task")
  func completingTheReopenedTaskAgainDoesNotMakeASecondNextTask() {
    let events =
      Self.done + [
        reopened("t1", lamport: 7), completed("t1", id: "complete-t1-again", lamport: 8),
        recurred("t1", as: "t2", due: "2026-11-02", id: "recur-again", lamport: 9),
      ]

    let state = LibraryState.replay(events)

    #expect(state.view(.default).openTasks.map(\.id) == [TaskID("t2")])
    #expect(state.dueDate(of: TaskID("t2"))?.date == date(nextMonday))
  }

  @Test("the next task recurs in turn, with the rule it carried")
  func theNextTaskRecursInTurn() {
    let events = Self.done + [completed("t2", lamport: 7), recurred("t2", as: "t3", due: "2026-11-02", lamport: 8)]

    let state = LibraryState.replay(events)

    #expect(state.view(.default).openTasks.map(\.id) == [TaskID("t3")])
    #expect(state.repeatRule(of: TaskID("t3")) == weekly)
  }

  @Test("a project that is gone leaves the next task loose")
  func aProjectThatIsGoneLeavesTheNextTaskLoose() {
    let events =
      routine + [
        completed("t1", lamport: 5), projectCompleted("p1", lamport: 6),
        recurred("t1", as: "t2", due: nextMonday, lamport: 7),
      ]

    let state = LibraryState.replay(events)

    let open = state.view(.default).openTasks
    #expect(open.map(\.id) == [TaskID("t2")])
    #expect(open.first?.parentID == nil)
  }
}

/// A fixed sequence of numbers, so a shuffle is the same on every run.
private struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return state
  }
}

@Suite("When the id of the next task is worked out")
struct RecurringIDTests {
  @Test("it is the same for the same task, different for another, and never grows")
  func itIsTheSameForTheSameTask() {
    let first = TaskID.recurring(after: TaskID("t1"))
    let again = TaskID.recurring(after: TaskID("t1"))
    let other = TaskID.recurring(after: TaskID("t2"))
    let chained = TaskID.recurring(after: first)

    #expect(first == again)
    #expect(first != other)
    #expect(first != TaskID("t1"))
    #expect(chained != first)
    #expect(chained.rawValue.count == first.rawValue.count)
  }
}
