import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let monday = date("2026-10-19")

@MainActor
private func makeLibrary(
  _ events: [EventEnvelope] = [],
  now: Int = 0
) -> (LibraryViewModel, InMemoryEventLog) {
  let log = InMemoryEventLog(events)
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()), today: { monday },
    now: { now })
  library.reload()
  return (library, log)
}

/// Three clarified tasks: an A of 60 minutes, a B of 30 and a C with no estimate.
private let clarified = [
  captured("t1", "write report", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
  estimated("t1", as: 60, lamport: 3),
  captured("t2", "call bank", lamport: 4), prioritized("t2", as: .important, lamport: 5),
  estimated("t2", as: 30, lamport: 6),
]

@MainActor
@Suite("When a weekday's default hours are reset in the settings")
struct ResetDayHoursTests {
  @Test("they go back to nine to five")
  func theyGoBackToNineToFive() {
    let (library, _) = makeLibrary()
    library.changeGlobalDayHours(.monday, start: 480, end: 960)

    library.resetGlobalDayHours(.monday)

    #expect(library.globalSettings.dayHours[.monday] == .builtIn)
  }
}

@MainActor
@Suite("When the day shown is laid out as a calendar")
struct PlacingInTheDayTests {
  static let planned = clarified + [scheduled("t1", on: "2026-10-19", lamport: 9)]

  @Test("placing a candidate plans it at the minute given")
  func placingACandidatePlansItAtTheMinuteGiven() {
    let (library, _) = makeLibrary(clarified)

    library.place(TaskID("t2"), atMinute: 780)

    #expect(library.plan.entries.map(\.task.title) == ["call bank"])
    #expect(library.planSlots.map(\.start) == [780])
  }

  @Test("placing a planned task again moves it, and nil lets it follow the others")
  func placingAPlannedTaskAgainMovesIt() {
    let (library, _) = makeLibrary(Self.planned)

    library.place(TaskID("t1"), atMinute: 900)
    #expect(library.planSlots.map(\.start) == [900])
    library.place(TaskID("t1"), atMinute: nil)
    #expect(library.planSlots.map(\.start) == [540])
  }

  @Test("a time outside the day changes nothing")
  func aTimeOutsideTheDayChangesNothing() {
    let (library, log) = makeLibrary(Self.planned)
    let before = log.events.count

    library.place(TaskID("t1"), atMinute: 2000)

    #expect(log.events.count == before)
  }

  @Test("on today the tasks that follow start no earlier than now, to the quarter hour")
  func onTodayTheTasksThatFollowStartNoEarlierThanNow() {
    let (library, _) = makeLibrary(Self.planned, now: 601)

    #expect(library.planSlots.map(\.start) == [615])
  }

  @Test("another day is laid out from the start of its day whatever the time now")
  func anotherDayIsLaidOutFromItsStart() {
    let (library, _) = makeLibrary(Self.planned, now: 601)

    library.showNextDay()
    library.addToPlan(TaskID("t2"))

    #expect(library.planSlots.map(\.start) == [540])
  }

  @Test("taking a task off the plan sends it back to the candidates")
  func takingATaskOffThePlanSendsItBack() {
    let (library, _) = makeLibrary(Self.planned)
    library.place(TaskID("t1"), atMinute: 900)

    library.removeFromPlan(TaskID("t1"))

    #expect(library.plan.entries.isEmpty)
    #expect(library.plan.candidates.map(\.task.title).contains("write report"))
  }
}

@Suite("When a time of day is written out")
struct ClockTextTests {
  @Test(
    "it shows hours and minutes after midnight",
    arguments: [(0, "00:00"), (540, "09:00"), (1005, "16:45"), (1440, "00:00"), (1500, "01:00")])
  func itShowsHoursAndMinutes(minutes: Int, text: String) {
    #expect(clockText(minutes) == text)
  }
}

@MainActor
@Suite("When blocks of untracked time are put on the day shown")
struct DayBlockViewModelTests {
  @Test("adding a block shows it in the plan, a blank title making it a Break")
  func addingABlockShowsIt() {
    let (library, _) = makeLibrary()

    library.addBlock(title: "Lunch", start: 750, end: 810)
    library.addBlock(title: " ", start: 900, end: 930)

    #expect(library.plan.blocks.map(\.title).sorted() == ["Break", "Lunch"])
  }

  @Test("moving a block keeps its length and stops when the day changes")
  func movingABlockKeepsItsLength() throws {
    let (library, _) = makeLibrary([blockSet("b1", "Lunch", 750, 810, on: "2026-10-19", lamport: 1)])

    library.moveBlock(BlockID("b1"), toStart: 840)
    #expect(library.plan.blocks.first?.start == 840)
    #expect(library.plan.blocks.first?.end == 900)
    library.moveBlock(BlockID("b1"), toStart: 5000)
    #expect(library.plan.blocks.first?.end == 1680)
  }

  @Test("changing a block, and removing it")
  func changingAndRemovingABlock() {
    let (library, _) = makeLibrary([blockSet("b1", "Lunch", 750, 810, on: "2026-10-19", lamport: 1)])

    library.updateBlock(BlockID("b1"), title: "Shopping", start: 600, end: 700)
    #expect(library.plan.blocks.first?.title == "Shopping")
    library.removeBlock(BlockID("b1"))
    #expect(library.plan.blocks.isEmpty)
  }
}
