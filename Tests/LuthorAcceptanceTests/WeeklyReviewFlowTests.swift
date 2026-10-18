import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

// "Move house" is created on Monday 2026-10-12 and "Learn Swift" on Wednesday 2026-10-14, so with the weekly
// default their reviews fall due on 2026-10-19 and 2026-10-21.

/// A log with the two projects, "pack boxes" filed in "Move house".
@MainActor
private func twoProjects(at url: URL) throws -> (house: TaskID, swift: TaskID) {
  let monday = launchApp(on: url, today: date("2026-10-12"))
  let house = try monday.createProject("Move house", kind: .parallel)
  monday.open(.project(house))
  monday.capture("pack boxes")
  let wednesday = launchApp(on: url, today: date("2026-10-14"))
  let swift = try wednesday.createProject("Learn Swift", kind: .parallel)
  return (house, swift)
}

@MainActor
@Suite("Given projects not looked at for a week, when I open the weekly review")
struct WeeklyReviewListFlowTests {
  @Test("it is a place on the rail, listing the projects whose review is due, oldest first")
  func itListsTheProjectsWhoseReviewIsDue() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let (house, swift) = try twoProjects(at: url)
    let library = launchApp(on: url, today: date("2026-10-21"))
    _ = try library.createProject("Fresh start", kind: .parallel)

    library.show(.weeklyReview)

    #expect(NavigationSection.allCases.contains(.weeklyReview))
    #expect(library.section == .weeklyReview)
    #expect(library.projectReview.map(\.project.id) == [house, swift])
    #expect(library.projectReview.map(\.nextReview) == [date("2026-10-19"), date("2026-10-21")])
  }

  @Test("the first project is picked, with its tasks shown to work on in place")
  func theFirstProjectIsPickedWithItsTasks() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let (house, swift) = try twoProjects(at: url)
    let library = launchApp(on: url, today: date("2026-10-21"))

    library.show(.weeklyReview)
    #expect(library.reviewProjectID == house)
    #expect(library.tasks.map(\.title) == ["pack boxes"])

    library.showReviewProject(swift)
    #expect(library.reviewProjectID == swift)
    #expect(library.tasks.isEmpty)

    library.showReviewProject(house)
    library.capture("book a van")
    #expect(library.tasks.map(\.title) == ["pack boxes", "book a van"])
  }

  @Test("nothing is due before a week has passed")
  func nothingIsDueBeforeAWeekHasPassed() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    _ = try twoProjects(at: url)
    let library = launchApp(on: url, today: date("2026-10-18"))

    library.show(.weeklyReview)

    #expect(library.projectReview.isEmpty)
    #expect(library.reviewProjectID == nil)
    #expect(library.tasks.isEmpty)
  }
}

@MainActor
@Suite("Given a project due for review, when I mark it reviewed")
struct WeeklyReviewMarkFlowTests {
  @Test("it leaves the list and the next project is picked, and a relaunch still has it reviewed")
  func itLeavesTheListAndTheNextProjectIsPicked() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let (house, swift) = try twoProjects(at: url)
    let library = launchApp(on: url, today: date("2026-10-21"))
    library.show(.weeklyReview)

    library.markProjectReviewed()

    #expect(library.projectReview.map(\.project.id) == [swift])
    #expect(library.reviewProjectID == swift)
    let relaunched = launchApp(on: url, today: date("2026-10-21"))
    relaunched.show(.weeklyReview)
    #expect(relaunched.projectReview.map(\.project.id) == [swift])
    #expect(relaunched.nextReviewDate(of: house) == date("2026-10-28"))
  }

  @Test("it is due again a week after the day it was reviewed")
  func itIsDueAgainAWeekLater() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let (house, swift) = try twoProjects(at: url)
    let library = launchApp(on: url, today: date("2026-10-21"))
    library.show(.weeklyReview)
    library.markProjectReviewed()
    library.markProjectReviewed()
    #expect(library.projectReview.isEmpty)
    #expect(library.reviewProjectID == nil)

    let sameWeek = launchApp(on: url, today: date("2026-10-27"))
    sameWeek.show(.weeklyReview)
    #expect(sameWeek.projectReview.isEmpty)

    let nextWeek = launchApp(on: url, today: date("2026-10-28"))
    nextWeek.show(.weeklyReview)
    #expect(nextWeek.projectReview.map(\.project.id) == [house, swift])
  }
}

@MainActor
@Suite("Given the weekly default, when I change how often projects are reviewed")
struct WeeklyReviewIntervalFlowTests {
  @Test("turning review off for everything empties the list, and a relaunch keeps it off")
  func turningReviewOffEmptiesTheList() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let (house, _) = try twoProjects(at: url)
    let library = launchApp(on: url, today: date("2026-10-21"))
    #expect(library.reviewDefault == .every(days: 7))

    library.setReviewDefault(.off)

    #expect(library.reviewDefault == .off)
    #expect(library.projectReview.isEmpty)
    #expect(library.nextReviewDate(of: house) == nil)
    let relaunched = launchApp(on: url, today: date("2026-10-21"))
    #expect(relaunched.reviewDefault == .off)
    #expect(relaunched.projectReview.isEmpty)
  }

  @Test("one project can have its own interval, and clearing it falls back to the default")
  func oneProjectCanHaveItsOwnInterval() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let (house, _) = try twoProjects(at: url)
    let library = launchApp(on: url, today: date("2026-10-16"))
    library.setReviewDefault(.off)
    #expect(library.projectReview.isEmpty)

    library.setReviewInterval(of: house, to: .every(days: 3))
    #expect(library.reviewInterval(of: house) == .every(days: 3))
    #expect(library.projectReview.map(\.project.id) == [house])
    #expect(library.nextReviewDate(of: house) == date("2026-10-15"))

    library.setReviewInterval(of: house, to: nil)
    #expect(library.reviewInterval(of: house) == .off)
    #expect(library.projectReview.isEmpty)
  }

  @Test("a project can be left out of the review while the others stay in")
  func aProjectCanBeLeftOut() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let (house, swift) = try twoProjects(at: url)
    let library = launchApp(on: url, today: date("2026-10-21"))

    library.setReviewInterval(of: house, to: .off)

    #expect(library.projectReview.map(\.project.id) == [swift])
  }
}

@MainActor
@Suite("Given a project with an open task, when I drop it")
struct ProjectStatusFlowTests {
  @Test("it is not reviewed and hands out nothing, it is listed as dropped, and a relaunch keeps it dropped")
  func aDroppedProjectSkipsTheReview() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let (house, swift) = try twoProjects(at: url)
    let library = launchApp(on: url, today: date("2026-10-21"))
    library.show(.today)
    #expect(library.plan.candidates.map(\.task.title) == ["pack boxes"])
    library.show(.weeklyReview)

    library.dropProject(house)

    #expect(library.projectReview.map(\.project.id) == [swift])
    #expect(library.nextReviewDate(of: house) == nil)
    #expect(!library.projects.contains { $0.id == house })
    library.showCompleted = true
    #expect(library.knownProjects.contains { $0.id == house })
    library.show(.today)
    #expect(library.plan.candidates.isEmpty)
    let relaunched = launchApp(on: url, today: date("2026-10-21"))
    relaunched.show(.weeklyReview)
    #expect(relaunched.projectReview.map(\.project.id) == [swift])
  }
}
