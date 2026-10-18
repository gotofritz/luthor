import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let monday = date("2026-10-19")

@MainActor
private func makeLibrary(
  _ events: [EventEnvelope] = [],
  today: CalendarDate = date("2026-10-21")
) -> (LibraryViewModel, InMemoryEventLog) {
  let log = InMemoryEventLog(events)
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()), view: .default, today: { today })
  library.reload()
  return (library, log)
}

/// "Move house" (created Monday 2026-10-12, with "pack boxes" and the sequential "book a van" first) and "Learn
/// Swift" (created 2026-10-14), both due by 2026-10-21, "Fresh" not, and "Launch" in Work.
private let reviewable = [
  viewCreated("work", "Work", lamport: 0),
  projectCreated("p1", "Move house", on: "2026-10-12", lamport: 1),
  projectCreated("p2", "Learn Swift", on: "2026-10-14", lamport: 1),
  projectCreated("p3", "Fresh", on: "2026-10-21", lamport: 1),
  projectCreated("w1", "Launch", view: "work", on: "2026-10-12", lamport: 1),
  captured("t1", "pack boxes", lamport: 1), moved("t1", to: "p1", lamport: 2),
  captured("t2", "book a van", lamport: 1), moved("t2", to: "p1", lamport: 3),
]

@MainActor
@Suite("When the weekly review is shown")
struct WeeklyReviewPlaceTests {
  @Test("the rail has it after the daily review")
  func theRailHasItAfterTheDailyReview() {
    let sections = NavigationSection.allCases

    #expect(sections.firstIndex(of: .weeklyReview) == sections.firstIndex(of: .review).map { $0 + 1 })
  }

  @Test("the projects due are listed whichever place is shown, the longest overdue first")
  func theProjectsDueAreListed() {
    let (library, _) = makeLibrary(reviewable)

    #expect(library.section == .inbox)
    #expect(library.projectReview.map(\.project.title) == ["Move house", "Learn Swift"])
    #expect(library.projectReview.map(\.nextReview) == [date("2026-10-19"), date("2026-10-21")])
  }

  @Test("the first project is picked, and its tasks are listed")
  func theFirstProjectIsPicked() {
    let (library, _) = makeLibrary(reviewable)

    library.show(.weeklyReview)

    #expect(library.reviewProjectID == ProjectID("p1"))
    #expect(library.tasks.map(\.title) == ["pack boxes", "book a van"])
    #expect(library.nextActions == Set(library.tasks.map(\.id)))
  }

  @Test("picking another project lists its tasks and clears the selection")
  func pickingAnotherProject() {
    let (library, _) = makeLibrary(reviewable)
    library.show(.weeklyReview)
    library.selection = TaskID("t1")

    library.showReviewProject(ProjectID("p2"))

    #expect(library.reviewProjectID == ProjectID("p2"))
    #expect(library.tasks.isEmpty)
    #expect(library.selection == nil)
  }

  @Test("the tasks of a sequential project that it holds back are listed but not next actions")
  func tasksHeldBackAreNotNextActions() {
    let events =
      reviewable + [
        EventEnvelope(
          id: EventID("seq-p1"), deviceID: DeviceID("mac"), lamport: 4,
          payload: .projectKindChanged(ProjectKindChanged(projectID: ProjectID("p1"), kind: .sequential)))
      ]
    let (library, _) = makeLibrary(events)

    library.show(.weeklyReview)

    #expect(library.tasks.map(\.title) == ["pack boxes", "book a van"])
    #expect(library.nextActions == [TaskID("t1")])
  }

  @Test("a new task is captured into the project picked")
  func aNewTaskIsCapturedIntoTheProjectPicked() {
    let (library, log) = makeLibrary(reviewable)
    library.show(.weeklyReview)

    library.draft = "call the landlord"
    library.submit()

    #expect(library.tasks.map(\.title) == ["pack boxes", "book a van", "call the landlord"])
    #expect(library.draft == "")
    #expect(log.events.count == reviewable.count + 2)
  }

  @Test("with no project due nothing is picked and a new task goes to the inbox")
  func withNoProjectDueNothingIsPicked() {
    let (library, _) = makeLibrary(reviewable, today: date("2026-10-18"))

    library.show(.weeklyReview)

    #expect(library.projectReview.isEmpty)
    #expect(library.reviewProjectID == nil)
    #expect(library.tasks.isEmpty)
    library.draft = "buy milk"
    library.submit()
    #expect(library.tasks.isEmpty)
    library.show(.inbox)
    #expect(library.tasks.map(\.title) == ["buy milk"])
  }

  @Test("leaving the weekly review keeps the project picked, and the view's switch drops it")
  func leavingKeepsTheProjectPicked() {
    let (library, _) = makeLibrary(reviewable)
    library.show(.weeklyReview)
    library.showReviewProject(ProjectID("p2"))

    library.show(.today)
    #expect(library.reviewProjectID == ProjectID("p2"))
    library.show(.weeklyReview)
    #expect(library.reviewProjectID == ProjectID("p2"))

    library.showView(ViewID("work"))
    library.show(.weeklyReview)
    #expect(library.projectReview.map(\.project.title) == ["Launch"])
    #expect(library.reviewProjectID == ProjectID("w1"))
  }
}

@MainActor
@Suite("When a project is marked reviewed from the window")
struct MarkProjectReviewedViewModelTests {
  @Test("it leaves the list and the next project is picked")
  func itLeavesTheListAndTheNextIsPicked() {
    let (library, log) = makeLibrary(reviewable)
    library.show(.weeklyReview)

    library.markProjectReviewed()

    #expect(library.projectReview.map(\.project.title) == ["Learn Swift"])
    #expect(library.reviewProjectID == ProjectID("p2"))
    #expect(log.events.last == projectReviewed("p1", on: "2026-10-21", id: "id-1", lamport: 4))
  }

  @Test("marking the last project picks the one before it, and the last of all picks none")
  func markingTheLastProject() {
    let (library, _) = makeLibrary(reviewable)
    library.show(.weeklyReview)
    library.showReviewProject(ProjectID("p2"))

    library.markProjectReviewed()
    #expect(library.reviewProjectID == ProjectID("p1"))

    library.markProjectReviewed()
    #expect(library.projectReview.isEmpty)
    #expect(library.reviewProjectID == nil)
  }

  @Test("marking a project in the middle picks the one that takes its place")
  func markingAProjectInTheMiddle() {
    let events = reviewable + [projectCreated("p4", "Taxes", on: "2026-10-15", lamport: 1)]
    let (library, _) = makeLibrary(events, today: date("2026-10-22"))
    library.show(.weeklyReview)
    #expect(library.projectReview.map(\.project.title) == ["Move house", "Learn Swift", "Taxes"])
    library.showReviewProject(ProjectID("p2"))

    library.markProjectReviewed()

    #expect(library.reviewProjectID == ProjectID("p4"))
  }

  @Test("with no project picked it writes nothing")
  func withNoProjectPickedItWritesNothing() {
    let (library, log) = makeLibrary(reviewable, today: date("2026-10-18"))
    library.show(.weeklyReview)

    library.markProjectReviewed()

    #expect(log.events.count == reviewable.count)
  }

  @Test("a project dropped elsewhere since is not marked, and the list catches up")
  func aProjectDroppedElsewhereIsNotMarked() {
    let (library, log) = makeLibrary(reviewable)
    library.show(.weeklyReview)
    log.events.append(projectDropped("p1", lamport: 5))

    library.markProjectReviewed()

    #expect(log.events.count == reviewable.count + 1)
    #expect(library.projectReview.map(\.project.title) == ["Learn Swift"])
    #expect(library.reviewProjectID == ProjectID("p2"))
  }
}

@MainActor
@Suite("When review intervals and project status are changed from the window")
struct ProjectReviewSettingsViewModelTests {
  @Test("the default interval is weekly until it is set")
  func theDefaultIntervalIsWeekly() {
    let (library, _) = makeLibrary(reviewable)

    #expect(library.reviewDefault == .every(days: 7))
    #expect(library.reviewInterval(of: ProjectID("p1")) == .every(days: 7))
    #expect(library.reviewOverride(of: ProjectID("p1")) == nil)
    #expect(library.nextReviewDate(of: ProjectID("p1")) == date("2026-10-19"))
  }

  @Test("setting the default changes the list")
  func settingTheDefaultChangesTheList() {
    let (library, _) = makeLibrary(reviewable)

    library.setReviewDefault(.every(days: 30))
    #expect(library.reviewDefault == .every(days: 30))
    #expect(library.projectReview.isEmpty)

    library.setReviewDefault(.off)
    #expect(library.reviewDefault == .off)
    #expect(library.nextReviewDate(of: ProjectID("p1")) == nil)
  }

  @Test("a project's own interval beats the default, and clearing it falls back")
  func aProjectsOwnIntervalBeatsTheDefault() {
    let (library, _) = makeLibrary(reviewable)
    library.setReviewDefault(.off)

    library.setReviewInterval(of: ProjectID("p2"), to: .every(days: 2))
    #expect(library.reviewOverride(of: ProjectID("p2")) == .every(days: 2))
    #expect(library.projectReview.map(\.project.title) == ["Learn Swift"])

    library.setReviewInterval(of: ProjectID("p2"), to: nil)
    #expect(library.reviewOverride(of: ProjectID("p2")) == nil)
    #expect(library.projectReview.isEmpty)
  }

  @Test("putting a project on hold, resuming it and dropping it changes its status")
  func statusChanges() {
    let (library, _) = makeLibrary(reviewable)
    func status() -> ProjectStatus? { library.projects.first { $0.id == ProjectID("p1") }?.status }

    library.putOnHold(ProjectID("p1"))
    #expect(status() == .onHold)
    library.resume(ProjectID("p1"))
    #expect(status() == .active)
    library.dropProject(ProjectID("p1"))
    #expect(status() == .dropped)
    #expect(library.projectReview.map(\.project.title) == ["Learn Swift"])
    library.resume(ProjectID("p1"))
    #expect(status() == .active)
  }

  @Test("an on-hold project's tasks are dimmed in its project column")
  func anOnHoldProjectsTasksAreDimmed() {
    let (library, _) = makeLibrary(reviewable)
    library.open(.project(ProjectID("p1")))
    #expect(library.nextActions == [TaskID("t1"), TaskID("t2")])

    library.putOnHold(ProjectID("p1"))

    #expect(library.nextActions.isEmpty)
  }
}
