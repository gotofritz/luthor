import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

// Monday 2026-10-19 is the day the window is launched on unless a test says otherwise.

@MainActor
@Suite("Given a day that was planned and worked")
struct EndOfDayReviewFlowTests {
  /// "write report" (60m) is done; "call bank" (30m) and "tidy desk" (no estimate) are not.
  private func plannedDay(on url: URL) throws -> LibraryViewModel {
    let library = launchApp(on: url)
    library.capture("write report !a 60m")
    library.capture("call bank !b 30m")
    library.capture("tidy desk !c")
    library.show(.today)
    try library.addToPlan(library.task("write report"))
    try library.addToPlan(library.task("call bank"))
    try library.addToPlan(library.task("tidy desk"))
    try library.complete(library.task("write report"))
    return library
  }

  @Test("the review shows what was done and what was not, against the estimates")
  func theReviewShowsWhatWasDoneAndWhatWasNot() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = try plannedDay(on: dir.file("events.jsonl"))

    library.show(.review)

    #expect(library.review.done.map(\.task.title) == ["write report"])
    #expect(library.review.notDone.map(\.task.title) == ["call bank", "tidy desk"])
    #expect(library.review.done.map(\.minutes) == [60])
    // The unestimated "tidy desk" counts at the default estimate of 5 minutes, and is flagged.
    #expect(library.review.notDone.map(\.minutes) == [30, 5])
    #expect(library.review.notDone.map(\.isUnestimated) == [false, true])
    #expect(library.review.estimatedMinutes == 95)
    #expect(!library.review.isReviewed)
  }

  @Test("time logged by hand, planned or not, is set against the estimates and survives a relaunch")
  func timeLoggedByHandIsSetAgainstTheEstimates() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let library = try plannedDay(on: url)
    library.show(.review)
    let report = try #require(library.review.done.first).task.id

    library.logTime(report, minutes: 90)
    library.logUnplannedTime(minutes: 25)

    #expect(library.review.done.map(\.loggedMinutes) == [90])
    #expect(library.review.loggedMinutes == 90)
    #expect(library.review.unplannedMinutes == 25)
    let relaunched = launchApp(on: url)
    relaunched.show(.review)
    #expect(relaunched.review.done.map(\.loggedMinutes) == [90])
    #expect(relaunched.review.unplannedMinutes == 25)
  }

  @Test("reviewing the day keeps a one-line note, and the day stays reviewed after a relaunch")
  func reviewingTheDayKeepsAOneLineNote() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let library = try plannedDay(on: url)
    library.show(.review)

    library.reviewDay(note: "Too many calls, protect the morning")

    #expect(library.review.isReviewed)
    #expect(library.review.note == "Too many calls, protect the morning")
    let relaunched = launchApp(on: url)
    relaunched.show(.review)
    #expect(relaunched.review.isReviewed)
    #expect(relaunched.review.note == "Too many calls, protect the morning")
    relaunched.showPreviousDay()
    #expect(!relaunched.review.isReviewed)
  }

  @Test("the history shows what a task was estimated and what it took, and never changes the estimate")
  func theHistoryIsShownButNeverApplied() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = try plannedDay(on: dir.file("events.jsonl"))
    library.show(.review)
    let report = try #require(library.review.done.first).task.id

    library.logTime(report, minutes: 90)

    let history = try #require(library.estimateHistory(ofTask: report))
    #expect(history.estimatedMinutes == 60)
    #expect(history.loggedMinutes == 90)
    #expect(library.review.done.map(\.history) == [history])
    library.showView(.default)
    library.showCompleted = true
    #expect(library.tasks.first { $0.id == report }?.estimate == 60)
  }
}

@MainActor
@Suite("Given tasks left over from a day that was not reviewed")
struct CarryOverFlowTests {
  /// Monday's plan is left as it is; the app is then launched on Tuesday. "pay rent", "book dentist",
  /// "ask Sam", "learn piano" and "old idea" are all left over.
  private func leftOverFromMonday(on url: URL) throws {
    let monday = launchApp(on: url)
    monday.capture("pay rent !a 15m")
    monday.capture("book dentist !b 15m")
    monday.capture("ask Sam !b 30m")
    monday.capture("learn piano !c 30m")
    monday.capture("old idea !c 30m")
    monday.show(.today)
    for title in ["pay rent", "book dentist", "ask Sam", "learn piano", "old idea"] {
      try monday.addToPlan(monday.task(title))
    }
  }

  @Test("they show at the top of the next Today, not among the candidates")
  func theyShowAtTheTopOfTheNextToday() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    try leftOverFromMonday(on: url)

    let tuesday = launchApp(on: url, today: date("2026-10-20"))
    tuesday.show(.today)

    #expect(
      tuesday.carryOver.map(\.entry.task.title)
        == ["pay rent", "book dentist", "ask Sam", "learn piano", "old idea"])
    #expect(tuesday.carryOver.map(\.plannedFor) == Array(repeating: date("2026-10-19"), count: 5))
    #expect(tuesday.plan.entries.isEmpty)
    #expect(tuesday.plan.candidates.isEmpty)
    #expect(tuesday.tasks.map(\.title) == ["pay rent", "book dentist", "ask Sam", "learn piano", "old idea"])
  }

  @Test("each gets a decision, and a decided task leaves the leftovers")
  func eachGetsADecision() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    try leftOverFromMonday(on: url)
    let tuesday = launchApp(on: url, today: date("2026-10-20"))
    tuesday.show(.today)
    let rent = try tuesday.task("pay rent")
    let dentist = try tuesday.task("book dentist")
    let sam = try tuesday.task("ask Sam")
    let piano = try tuesday.task("learn piano")
    let idea = try tuesday.task("old idea")

    tuesday.addToPlan(rent)
    tuesday.deferToTomorrow(dentist)
    tuesday.delegate(sam, to: "Sam", followUp: nil)
    tuesday.sendToSomeday(piano)
    tuesday.dropTask(idea)

    #expect(tuesday.carryOver.isEmpty)
    #expect(tuesday.plan.entries.map(\.task.id) == [rent])
    tuesday.showNextDay()
    #expect(tuesday.plan.entries.map(\.task.id) == [dentist])
    #expect(tuesday.waiting.map(\.task.id) == [sam])
    tuesday.show(.priorities)
    tuesday.togglePriority(.someday)
    #expect(tuesday.tasks.map(\.id) == [piano])
  }

  @Test("sending one back to the list makes it a candidate again")
  func sendingOneBackToTheListMakesItACandidate() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    try leftOverFromMonday(on: url)
    let tuesday = launchApp(on: url, today: date("2026-10-20"))
    tuesday.show(.today)
    let rent = try tuesday.task("pay rent")

    tuesday.removeFromPlan(rent)

    #expect(!tuesday.carryOver.map(\.entry.task.id).contains(rent))
    #expect(tuesday.plan.candidates.map(\.task.id) == [rent])
  }

  @Test("nothing is carried over by itself: an unreviewed day is left as it is")
  func nothingIsCarriedOverByItself() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    try leftOverFromMonday(on: url)

    let wednesday = launchApp(on: url, today: date("2026-10-21"))
    wednesday.show(.today)

    #expect(wednesday.carryOver.count == 5)
    #expect(wednesday.carryOver.map(\.plannedFor) == Array(repeating: date("2026-10-19"), count: 5))
    #expect(wednesday.plan.entries.isEmpty)
  }
}
