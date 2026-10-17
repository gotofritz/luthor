import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

// Monday 2026-10-19 is the day the window is launched on: 480 minutes of capacity, a 40% buffer.

@MainActor
@Suite("Given clarified tasks, when the morning plan is made")
struct MorningPlanFlowTests {
  @Test("pulling tasks in fills the plan in priority order, with the buffer always in sight")
  func pullingTasksInFillsThePlanWithTheBufferInSight() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("tidy desk !c")
    library.capture("write report !a 120m")
    library.capture("call bank !b 30m")
    library.show(.today)

    #expect(library.plan.candidates.map(\.task.title) == ["write report", "call bank", "tidy desk"])
    try library.addToPlan(library.task("tidy desk"))
    try library.addToPlan(library.task("call bank"))
    try library.addToPlan(library.task("write report"))

    #expect(library.plan.entries.map(\.task.title) == ["write report", "call bank", "tidy desk"])
    #expect(library.plan.candidates.isEmpty)
    let capacity = library.plan.capacity
    #expect(capacity.availableMinutes == 480)
    #expect(capacity.bufferMinutes == 192)
    #expect(capacity.usableMinutes == 288)
    // The unestimated "tidy desk" counts at the default estimate of 5 minutes, and is flagged.
    #expect(capacity.plannedMinutes == 155)
    #expect(capacity.remainingMinutes == 133)
    #expect(capacity.unestimatedCount == 1)
    #expect(!capacity.isOverloaded)
    #expect(library.plan.entries.map(\.isUnestimated) == [false, false, true])
  }

  @Test("planning more than fits warns but still takes the task")
  func planningMoreThanFitsWarnsButStillTakesTheTask() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("migrate server !a 300m")
    library.show(.today)

    try library.addToPlan(library.task("migrate server"))

    #expect(library.plan.entries.map(\.task.title) == ["migrate server"])
    #expect(library.plan.capacity.isOverloaded)
    #expect(library.plan.capacity.remainingMinutes == -12)
  }

  @Test("a day's capacity can be set for that day alone")
  func aDaysCapacityCanBeSetForThatDayAlone() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let library = launchApp(on: url)
    library.show(.today)

    library.setDayCapacity(minutes: 240)

    #expect(library.plan.capacity.availableMinutes == 240)
    #expect(library.plan.capacity.bufferMinutes == 96)
    library.showNextDay()
    #expect(library.plan.capacity.availableMinutes == 480)
    let relaunched = launchApp(on: url)
    relaunched.show(.today)
    #expect(relaunched.plan.capacity.availableMinutes == 240)
  }
}

@MainActor
@Suite("Given a plan with an order of my own")
struct ManualOrderFlowTests {
  @Test("the order I chose wins over the suggested one and is kept after a relaunch")
  func theOrderIChoseWinsAndIsKept() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let library = launchApp(on: url)
    library.capture("write report !a 60m")
    library.capture("call bank !b 30m")
    library.capture("tidy desk !a 15m")
    library.show(.today)
    try library.addToPlan(library.task("write report"))
    try library.addToPlan(library.task("call bank"))
    #expect(library.plan.entries.map(\.task.title) == ["write report", "call bank"])

    try library.moveInPlan(library.task("call bank"), by: -1)
    try library.addToPlan(library.task("tidy desk"))

    // The new task follows the order I chose, although the suggestion would put its A first.
    #expect(library.plan.entries.map(\.task.title) == ["call bank", "write report", "tidy desk"])
    let relaunched = launchApp(on: url)
    relaunched.show(.today)
    #expect(relaunched.plan.entries.map(\.task.title) == ["call bank", "write report", "tidy desk"])
  }

  @Test("each suggested place is explained")
  func eachSuggestedPlaceIsExplained() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("write report !a 60m")
    library.show(.today)

    try library.addToPlan(library.task("write report"))

    #expect(library.plan.entries.map(\.reason) == ["A priority"])
  }
}

@MainActor
@Suite("Given a task in the plan")
struct DecideFromThePlanFlowTests {
  @Test("deferring it moves the same task to the next day and duplicates nothing")
  func deferringMovesTheSameTaskToTheNextDay() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("write report !a 60m")
    library.show(.today)
    let report = try library.task("write report")
    library.addToPlan(report)

    library.deferToTomorrow(report)

    #expect(library.plan.entries.isEmpty)
    library.showNextDay()
    #expect(library.plan.entries.map(\.task.id) == [report])
    #expect(library.plan.capacity.plannedMinutes == 60)
  }

  @Test("sending it to someday takes it out of the plan and of the candidates")
  func sendingItToSomedayTakesItOutOfThePlan() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("learn piano !a 30m")
    library.show(.today)
    let piano = try library.task("learn piano")
    library.addToPlan(piano)

    library.sendToSomeday(piano)

    #expect(library.plan.entries.isEmpty)
    #expect(library.plan.candidates.isEmpty)
    library.show(.priorities)
    library.togglePriority(.someday)
    #expect(library.tasks.map(\.id) == [piano])
  }

  @Test("dropping it removes the task from every list")
  func droppingItRemovesTheTaskFromEveryList() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("old idea !b 30m")
    library.show(.today)
    let idea = try library.task("old idea")
    library.addToPlan(idea)

    library.dropTask(idea)

    #expect(library.plan.entries.isEmpty)
    #expect(library.plan.candidates.isEmpty)
    library.show(.priorities)
    for priority in Priority.allCases { library.togglePriority(priority) }
    #expect(library.tasks.isEmpty)
  }
}

@MainActor
@Suite("Given a task delegated with a follow-up date")
struct DelegationFlowTests {
  @Test("it leaves the plan and its totals, waits in Waiting for, and returns on the follow-up date")
  func itLeavesThePlanWaitsAndReturnsOnTheFollowUpDate() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let library = launchApp(on: url)
    library.capture("get quote !b 30m")
    library.capture("write report !a 60m")
    library.show(.today)
    let quote = try library.task("get quote")
    try library.addToPlan(library.task("write report"))
    library.addToPlan(quote)

    library.delegate(quote, to: "Sam", followUp: date("2026-10-21"))

    #expect(library.plan.entries.map(\.task.title) == ["write report"])
    #expect(library.plan.candidates.isEmpty)
    #expect(library.plan.capacity.plannedMinutes == 60)
    #expect(library.waiting.map(\.delegation.to) == ["Sam"])
    #expect(library.waiting.map(\.delegation.since) == [date("2026-10-19")])
    #expect(library.waiting.map(\.isFollowUpDue) == [false])

    let onFollowUpDay = launchApp(on: url, today: date("2026-10-21"))
    onFollowUpDay.show(.today)
    #expect(onFollowUpDay.plan.candidates.map(\.task.title) == ["get quote"])
    #expect(onFollowUpDay.waiting.map(\.isFollowUpDue) == [true])
  }

  @Test("reclaiming it makes it a candidate again, and nothing was completed or dropped")
  func reclaimingItMakesItACandidateAgain() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("get quote !b 30m")
    library.show(.today)
    let quote = try library.task("get quote")
    library.delegate(quote, to: "Sam", followUp: nil)
    #expect(library.plan.candidates.isEmpty)

    library.reclaim(quote)

    #expect(library.waiting.isEmpty)
    #expect(library.plan.candidates.map(\.task.id) == [quote])
  }
}

@MainActor
@Suite("Given two views")
struct PlanPerViewFlowTests {
  @Test("the work day and the private evening are planned apart")
  func theWorkDayAndThePrivateEveningArePlannedApart() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let work = try library.createView("Work")
    library.capture("write report !a 60m")
    library.show(.today)
    try library.addToPlan(library.task("write report"))
    library.setDayCapacity(minutes: 300)

    library.showView(.default)
    library.show(.today)

    #expect(library.plan.entries.isEmpty)
    #expect(library.plan.candidates.isEmpty)
    #expect(library.plan.capacity.availableMinutes == 480)
    library.showView(work)
    library.show(.today)
    #expect(library.plan.entries.map(\.task.title) == ["write report"])
    #expect(library.plan.capacity.availableMinutes == 300)
  }
}
