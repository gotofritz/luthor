import LuthorDomain
import LuthorTestSupport
import Testing

private let monday = date("2026-10-19")

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a day's hours are worked out")
struct DayHoursTests {
  private func hours(_ events: [EventEnvelope], on day: CalendarDate = monday, view: String = "default") -> DayHours {
    LibraryState.replay(events).hours(in: ViewID(view), on: day)
  }

  @Test("a day starts at nine and ends at five unless told otherwise")
  func aDayStartsAtNineAndEndsAtFive() {
    #expect(hours([]) == DayHours(start: 540, end: 1020))
  }

  @Test("a weekday's hours from the settings beat the built-in ones, for that weekday only")
  func aWeekdaysHoursBeatTheBuiltInOnes() {
    let events = [
      settingChanged(.dayStartMonday, to: "480", lamport: 1), settingChanged(.dayEndMonday, to: "960", lamport: 2),
    ]

    #expect(hours(events) == DayHours(start: 480, end: 960))
    #expect(hours(events, on: date("2026-10-20")) == .builtIn)
  }

  @Test("a view's own weekday hours beat the global ones")
  func aViewsOwnWeekdayHoursBeatTheGlobalOnes() {
    let events = [
      viewCreated("work", "Work", lamport: 1), settingChanged(.dayStartMonday, to: "480", lamport: 2),
      settingChanged(.dayStartMonday, to: "600", view: "work", lamport: 3),
    ]

    #expect(hours(events, view: "work").start == 600)
    #expect(hours(events).start == 480)
  }

  @Test("hours from the settings that do not fit a day fall back to the built-in ones")
  func hoursThatDoNotFitADayFallBack() {
    let events = [
      settingChanged(.dayStartMonday, to: "1200", lamport: 1), settingChanged(.dayEndMonday, to: "600", lamport: 2),
    ]

    #expect(hours(events) == .builtIn)
  }

  @Test("hours set for the day beat the weekday's")
  func hoursSetForTheDayBeatTheWeekdays() {
    let events = [
      settingChanged(.dayStartMonday, to: "480", lamport: 1), dayHoursSet(600, 1080, on: "2026-10-19", lamport: 2),
    ]

    #expect(hours(events) == DayHours(start: 600, end: 1080))
    #expect(hours(events, on: date("2026-10-26")) == DayHours(start: 480, end: 1020))
  }

  @Test("clearing the day's hours goes back to the weekday's")
  func clearingTheDaysHoursGoesBackToTheWeekdays() {
    let events = [
      dayHoursSet(600, 1080, on: "2026-10-19", lamport: 1), dayHoursSet(nil, nil, on: "2026-10-19", lamport: 2),
    ]

    #expect(hours(events) == .builtIn)
  }

  @Test("another view is not touched by the day's hours")
  func anotherViewIsNotTouched() {
    let events = [viewCreated("work", "Work", lamport: 1), dayHoursSet(600, 1080, on: "2026-10-19", lamport: 2)]

    #expect(hours(events, view: "work") == .builtIn)
  }

  @Test("hours that do not make a day in the log clear the day's own")
  func hoursThatDoNotMakeADayClearTheDaysOwn() {
    let events = [
      dayHoursSet(600, 1080, on: "2026-10-19", lamport: 1), dayHoursSet(1000, 900, on: "2026-10-19", lamport: 2),
    ]

    #expect(hours(events) == .builtIn)
  }
}

@Suite("When a day's hours are set by command")
struct DayHoursCommandTests {
  @Test("it writes one DayHoursSet")
  func itWritesOneDayHoursSet() throws {
    let events = try makeCommands().setHours(DayHours(start: 480, end: 960), for: .default, on: monday, log: [])

    #expect(events == [dayHoursSet(480, 960, on: "2026-10-19", id: "id-1", lamport: 1)])
  }

  @Test("clearing writes one DayHoursSet without hours")
  func clearingWritesOneDayHoursSetWithoutHours() throws {
    let log = [dayHoursSet(480, 960, on: "2026-10-19", lamport: 1)]

    let events = try makeCommands().setHours(nil, for: .default, on: monday, log: log)

    #expect(events == [dayHoursSet(nil, nil, on: "2026-10-19", id: "id-1", lamport: 2)])
  }

  @Test("setting the hours a day has writes nothing")
  func settingTheHoursADayHasWritesNothing() throws {
    let log = [dayHoursSet(480, 960, on: "2026-10-19", lamport: 1)]

    #expect(try makeCommands().setHours(DayHours(start: 480, end: 960), for: .default, on: monday, log: log).isEmpty)
    #expect(try makeCommands().setHours(nil, for: .default, on: date("2026-10-20"), log: []).isEmpty)
  }

  @Test("hours that end before they start are refused", arguments: [(600, 600), (700, 600), (-1, 600), (0, 1500)])
  func hoursThatDoNotFitADayAreRefused(start: Int, end: Int) {
    #expect(throws: CommandError.invalidHours) {
      try makeCommands().setHours(DayHours(start: start, end: end), for: .default, on: monday, log: [])
    }
  }

  @Test("a view that does not exist is refused")
  func aViewThatDoesNotExistIsRefused() {
    #expect(throws: CommandError.noView(ViewID("gone"))) {
      try makeCommands().setHours(nil, for: ViewID("gone"), on: monday, log: [])
    }
  }
}

@Suite("When a day's plan is laid out on its hours")
struct PlanSlotTests {
  private let events = [
    captured("t1", "write report", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
    estimated("t1", as: 60, lamport: 3), scheduled("t1", on: "2026-10-19", lamport: 4),
    captured("t2", "call bank", lamport: 5), prioritized("t2", as: .important, lamport: 6),
    estimated("t2", as: 30, lamport: 7), scheduled("t2", on: "2026-10-19", lamport: 8),
  ]

  @Test("tasks follow one another from the start of the day, as long as their minutes")
  func tasksFollowOneAnotherFromTheStartOfTheDay() {
    let plan = LibraryState.replay(events).plan(for: .default, on: monday, today: monday)

    #expect(plan.slots().map(\.entry.task.title) == ["write report", "call bank"])
    #expect(plan.slots().map(\.start) == [540, 600])
    #expect(plan.slots().map(\.end) == [600, 630])
  }

  @Test("the day's own hours move them")
  func theDaysOwnHoursMoveThem() {
    let plan = LibraryState.replay(events + [dayHoursSet(480, 960, on: "2026-10-19", lamport: 9)])
      .plan(for: .default, on: monday, today: monday)

    #expect(plan.hours == DayHours(start: 480, end: 960))
    #expect(plan.slots().map(\.start) == [480, 540])
  }

  @Test("an empty plan has no slots")
  func anEmptyPlanHasNoSlots() {
    #expect(LibraryState.replay([]).plan(for: .default, on: monday, today: monday).slots().isEmpty)
  }
}

@Suite("When a planned task is given a start of its own")
struct TaskStartTests {
  private let events = [
    captured("t1", "write report", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
    estimated("t1", as: 60, lamport: 3), scheduled("t1", on: "2026-10-19", lamport: 4),
    captured("t2", "call bank", lamport: 5), prioritized("t2", as: .important, lamport: 6),
    estimated("t2", as: 30, lamport: 7), scheduled("t2", on: "2026-10-19", lamport: 8),
  ]

  private func plan(_ more: [EventEnvelope] = []) -> DayPlan {
    LibraryState.replay(events + more).plan(for: .default, on: monday, today: monday)
  }

  @Test("it stands where it was told to, and the others follow from the start of the day")
  func itStandsWhereItWasToldTo() {
    let slots = plan([startSet("t1", 780, on: "2026-10-19", lamport: 9)]).slots()

    #expect(slots.map(\.entry.task.title) == ["call bank", "write report"])
    #expect(slots.map(\.start) == [540, 780])
  }

  @Test("the tasks that follow do not start before the time given, such as now")
  func theTasksThatFollowDoNotStartBeforeNow() {
    #expect(plan().slots(notBefore: 600).map(\.start) == [600, 660])
    #expect(plan().slots(notBefore: 300).map(\.start) == [540, 600])
  }

  @Test("the tasks that follow go round a task with a start of its own")
  func theTasksThatFollowGoRoundIt() {
    let slots = plan([startSet("t2", 570, on: "2026-10-19", lamport: 9)]).slots()

    #expect(slots.map(\.entry.task.title) == ["call bank", "write report"])
    #expect(slots.map(\.start) == [570, 600])
  }

  @Test("clearing it lets the task follow the others again")
  func clearingItLetsTheTaskFollowAgain() {
    let cleared = [
      startSet("t1", 780, on: "2026-10-19", lamport: 9), startSet("t1", nil, on: "2026-10-19", lamport: 10),
    ]

    #expect(plan(cleared).slots().map(\.start) == [540, 600])
  }

  @Test("it is lost when the task is planned for another day, or taken off the plan")
  func itIsLostWhenThePlanChanges() {
    let started = [startSet("t1", 780, on: "2026-10-19", lamport: 9)]

    let toTuesday = scheduled("t1", on: "2026-10-20", lamport: 10)
    let toMonday = scheduled("t1", on: "2026-10-19", lamport: 11)
    let moved = LibraryState.replay(events + started + [toTuesday])
    let back = LibraryState.replay(events + started + [toTuesday, toMonday])
    let off = LibraryState.replay(events + started + [unscheduled("t1", lamport: 10), toMonday])

    #expect(moved.startMinute(of: TaskID("t1"), on: date("2026-10-20")) == nil)
    #expect(back.startMinute(of: TaskID("t1"), on: monday) == nil)
    #expect(off.startMinute(of: TaskID("t1"), on: monday) == nil)
  }

  @Test("a start for a task that is not planned that day is ignored")
  func aStartForATaskNotPlannedThatDayIsIgnored() {
    let state = LibraryState.replay(events + [startSet("t1", 780, on: "2026-10-20", lamport: 9)])

    #expect(state.startMinute(of: TaskID("t1"), on: date("2026-10-20")) == nil)
    #expect(state.startMinute(of: TaskID("t1"), on: monday) == nil)
  }
}

@Suite("When a task's start is set by command")
struct TaskStartCommandTests {
  private let log = [captured("t1", "write report", lamport: 1)]

  @Test("it plans the task for the day, then sets the start")
  func itPlansTheTaskThenSetsTheStart() throws {
    let events = try makeCommands().setStart(taskID: TaskID("t1"), on: monday, minute: 600, log: log)

    let scheduling = EventPayload.taskScheduled(TaskScheduled(taskID: TaskID("t1"), date: monday))
    let start = EventPayload.taskStartSet(TaskStartSet(taskID: TaskID("t1"), date: monday, minute: 600))
    #expect(events.map(\.payload) == [scheduling, start])
  }

  @Test("on a task already planned that day it writes the start alone, and nothing for the same start")
  func onAPlannedTaskItWritesTheStartAlone() throws {
    let planned = log + [scheduled("t1", on: "2026-10-19", lamport: 2)]

    let events = try makeCommands().setStart(taskID: TaskID("t1"), on: monday, minute: 600, log: planned)
    let started = planned + [startSet("t1", 600, on: "2026-10-19", lamport: 3)]
    let again = try makeCommands().setStart(taskID: TaskID("t1"), on: monday, minute: 600, log: started)

    #expect(events == [startSet("t1", 600, on: "2026-10-19", id: "id-1", lamport: 3)])
    #expect(again.isEmpty)
  }

  @Test("clearing the start of a task that is not planned that day writes nothing")
  func clearingTheStartOfAnUnplannedTaskWritesNothing() throws {
    #expect(try makeCommands().setStart(taskID: TaskID("t1"), on: monday, minute: nil, log: log).isEmpty)
  }

  @Test("a minute outside the day is refused", arguments: [-1, 1440])
  func aMinuteOutsideTheDayIsRefused(minute: Int) {
    #expect(throws: CommandError.invalidHours) {
      try makeCommands().setStart(taskID: TaskID("t1"), on: monday, minute: minute, log: log)
    }
  }

  @Test("a task that is not open is refused")
  func aTaskThatIsNotOpenIsRefused() {
    #expect(throws: CommandError.noOpenTask("gone")) {
      try makeCommands().setStart(taskID: TaskID("gone"), on: monday, minute: 600, log: log)
    }
  }
}
