import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a task is scheduled by command")
struct ScheduleCommandTests {
  static let log = [captured("t1", "write report", lamport: 1)]

  @Test("it writes one TaskScheduled")
  func itWritesOneTaskScheduled() throws {
    let events = try makeCommands().schedule(taskID: TaskID("t1"), on: date("2026-10-19"), log: Self.log)

    #expect(events == [scheduled("t1", on: "2026-10-19", id: "id-1", lamport: 2)])
  }

  @Test("scheduling it for the day it already has writes nothing")
  func schedulingForTheSameDayWritesNothing() throws {
    let log = Self.log + [scheduled("t1", on: "2026-10-19", lamport: 2)]

    #expect(try makeCommands().schedule(taskID: TaskID("t1"), on: date("2026-10-19"), log: log) == [])
  }

  @Test("scheduling it for another day moves it")
  func schedulingForAnotherDayMovesIt() throws {
    let log = Self.log + [scheduled("t1", on: "2026-10-19", lamport: 2)]

    let events = try makeCommands().schedule(taskID: TaskID("t1"), on: date("2026-10-20"), log: log)

    #expect(events == [scheduled("t1", on: "2026-10-20", id: "id-1", lamport: 3)])
  }

  @Test("a task that is not open is refused")
  func aTaskThatIsNotOpenIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().schedule(taskID: TaskID("t9"), on: date("2026-10-19"), log: Self.log)
    }
  }

  @Test("a someday task has to be promoted first")
  func aSomedayTaskHasToBePromotedFirst() {
    let log = Self.log + [prioritized("t1", as: .someday, lamport: 2)]

    #expect(throws: CommandError.someday(TaskID("t1"))) {
      try makeCommands().schedule(taskID: TaskID("t1"), on: date("2026-10-19"), log: log)
    }
  }

  @Test("a delegated task is reclaimed first, so scheduling it takes it back")
  func aDelegatedTaskIsReclaimedFirst() throws {
    let log = Self.log + [delegated("t1", to: "Sam", lamport: 2)]

    let events = try makeCommands().schedule(taskID: TaskID("t1"), on: date("2026-10-20"), log: log)

    #expect(
      events == [reclaimed("t1", id: "id-1", lamport: 3), scheduled("t1", on: "2026-10-20", id: "id-2", lamport: 4)])
  }

  @Test("unscheduling writes one TaskUnscheduled, and nothing for a task with no day")
  func unschedulingWritesOneTaskUnscheduled() throws {
    let log = Self.log + [scheduled("t1", on: "2026-10-19", lamport: 2)]

    let events = try makeCommands().unschedule(taskID: TaskID("t1"), log: log)

    #expect(events == [unscheduled("t1", id: "id-1", lamport: 3)])
    #expect(try makeCommands().unschedule(taskID: TaskID("t1"), log: Self.log) == [])
  }

  @Test("unscheduling a task that is not open is refused")
  func unschedulingATaskThatIsNotOpenIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().unschedule(taskID: TaskID("t9"), log: Self.log)
    }
  }
}

@Suite("When the order of a day's plan is set by command")
struct OrderPlanCommandTests {
  static let log = [captured("t1", "write report", lamport: 1), captured("t2", "call bank", lamport: 2)]

  @Test("it writes one DayPlanOrdered")
  func itWritesOneDayPlanOrdered() throws {
    let events = try makeCommands().orderPlan(
      of: .default, on: date("2026-10-19"), as: [TaskID("t2"), TaskID("t1")], log: Self.log)

    #expect(events == [planOrdered(["t2", "t1"], on: "2026-10-19", id: "id-1", lamport: 3)])
  }

  @Test("the order it already has writes nothing")
  func theOrderItAlreadyHasWritesNothing() throws {
    let log = Self.log + [planOrdered(["t2", "t1"], on: "2026-10-19", lamport: 3)]

    let events = try makeCommands().orderPlan(
      of: .default, on: date("2026-10-19"), as: [TaskID("t2"), TaskID("t1")], log: log)

    #expect(events == [])
  }

  @Test("a task that is not open in the view is refused")
  func aTaskThatIsNotOpenInTheViewIsRefused() {
    let log = Self.log + [viewCreated("work", "Work", lamport: 3)]

    #expect(throws: CommandError.noOpenTask("t1")) {
      try makeCommands().orderPlan(of: ViewID("work"), on: date("2026-10-19"), as: [TaskID("t1")], log: log)
    }
  }

  @Test("a view that does not exist is refused")
  func aViewThatDoesNotExistIsRefused() {
    #expect(throws: CommandError.noView(ViewID("gone"))) {
      try makeCommands().orderPlan(of: ViewID("gone"), on: date("2026-10-19"), as: [], log: Self.log)
    }
  }
}

@Suite("When a day's capacity is set by command")
struct DayCapacityCommandTests {
  @Test("it writes one DayCapacitySet")
  func itWritesOneDayCapacitySet() throws {
    let events = try makeCommands().setCapacity(240, for: .default, on: date("2026-10-19"), log: [])

    #expect(events == [dayCapacitySet(240, on: "2026-10-19", id: "id-1", lamport: 1)])
  }

  @Test("clearing it writes one DayCapacitySet without minutes")
  func clearingItWritesOneDayCapacitySetWithoutMinutes() throws {
    let log = [dayCapacitySet(240, on: "2026-10-19", lamport: 1)]

    let events = try makeCommands().setCapacity(nil, for: .default, on: date("2026-10-19"), log: log)

    #expect(events == [dayCapacitySet(nil, on: "2026-10-19", id: "id-1", lamport: 2)])
  }

  @Test("setting the capacity a day has writes nothing")
  func settingTheCapacityADayHasWritesNothing() throws {
    let log = [dayCapacitySet(240, on: "2026-10-19", lamport: 1)]

    #expect(try makeCommands().setCapacity(240, for: .default, on: date("2026-10-19"), log: log) == [])
    #expect(try makeCommands().setCapacity(nil, for: .default, on: date("2026-10-20"), log: log) == [])
  }

  @Test("a view that does not exist is refused")
  func aViewThatDoesNotExistIsRefused() {
    #expect(throws: CommandError.noView(ViewID("gone"))) {
      try makeCommands().setCapacity(240, for: ViewID("gone"), on: date("2026-10-19"), log: [])
    }
  }
}

@Suite("When a task is delegated by command")
struct DelegateCommandTests {
  static let log = [captured("t1", "get quote", lamport: 1), scheduled("t1", on: "2026-10-19", lamport: 2)]

  @Test("it writes one TaskDelegated with who, since when and the follow-up date")
  func itWritesOneTaskDelegated() throws {
    let events = try makeCommands().delegate(
      taskID: TaskID("t1"), to: "  Sam ", since: date("2026-10-19"), followUp: date("2026-10-21"), log: Self.log)

    #expect(events == [delegated("t1", to: "Sam", followUp: "2026-10-21", id: "id-1", lamport: 3)])
  }

  @Test("delegating again to the same person on the same terms writes nothing")
  func delegatingAgainOnTheSameTermsWritesNothing() throws {
    let log = Self.log + [delegated("t1", to: "Sam", followUp: "2026-10-21", lamport: 3)]

    let events = try makeCommands().delegate(
      taskID: TaskID("t1"), to: "Sam", since: date("2026-10-19"), followUp: date("2026-10-21"), log: log)

    #expect(events == [])
  }

  @Test("a blank name is refused")
  func aBlankNameIsRefused() {
    #expect(throws: CommandError.blankTitle) {
      try makeCommands().delegate(
        taskID: TaskID("t1"), to: "   ", since: date("2026-10-19"), followUp: nil, log: Self.log)
    }
  }

  @Test("a task that is not open is refused")
  func aTaskThatIsNotOpenIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().delegate(
        taskID: TaskID("t9"), to: "Sam", since: date("2026-10-19"), followUp: nil, log: Self.log)
    }
  }

  @Test("reclaiming writes one TaskReclaimed, and nothing for a task that is not delegated")
  func reclaimingWritesOneTaskReclaimed() throws {
    let log = Self.log + [delegated("t1", to: "Sam", lamport: 3)]

    #expect(try makeCommands().reclaim(taskID: TaskID("t1"), log: log) == [reclaimed("t1", id: "id-1", lamport: 4)])
    #expect(try makeCommands().reclaim(taskID: TaskID("t1"), log: Self.log) == [])
  }

  @Test("reclaiming a task that is not open is refused")
  func reclaimingATaskThatIsNotOpenIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().reclaim(taskID: TaskID("t9"), log: Self.log)
    }
  }
}

@Suite("When a task is dropped or sent to someday by command")
struct DecideCommandTests {
  static let log = [captured("t1", "old idea", lamport: 1), scheduled("t1", on: "2026-10-19", lamport: 2)]

  @Test("dropping writes one TaskDropped")
  func droppingWritesOneTaskDropped() throws {
    #expect(try makeCommands().drop(taskID: TaskID("t1"), log: Self.log) == [dropped("t1", id: "id-1", lamport: 3)])
  }

  @Test("dropping a task that is not open is refused")
  func droppingATaskThatIsNotOpenIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().drop(taskID: TaskID("t9"), log: Self.log)
    }
  }

  @Test("sending to someday takes the task off its day and gives it the someday priority")
  func sendingToSomedayTakesTheTaskOffItsDay() throws {
    let events = try makeCommands().sendToSomeday(taskID: TaskID("t1"), log: Self.log)

    #expect(
      events == [unscheduled("t1", id: "id-1", lamport: 3), prioritized("t1", as: .someday, id: "id-2", lamport: 4)])
  }

  @Test("sending an unscheduled task to someday only gives it the priority")
  func sendingAnUnscheduledTaskToSomedayOnlyGivesItThePriority() throws {
    let log = [captured("t1", "old idea", lamport: 1)]

    let events = try makeCommands().sendToSomeday(taskID: TaskID("t1"), log: log)

    #expect(events == [prioritized("t1", as: .someday, id: "id-1", lamport: 2)])
  }

  @Test("sending a task that is not open to someday is refused")
  func sendingATaskThatIsNotOpenToSomedayIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().sendToSomeday(taskID: TaskID("t9"), log: Self.log)
    }
  }
}
