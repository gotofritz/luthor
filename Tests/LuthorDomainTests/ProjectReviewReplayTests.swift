import LuthorDomain
import LuthorTestSupport
import Testing

// Two projects in the default view: "Move house" created on Monday 2026-10-12 and "Learn Swift" on
// Wednesday 2026-10-14, plus one in Work.
private let projects = [
  viewCreated("work", "Work", lamport: 0),
  projectCreated("p1", "Move house", on: "2026-10-12", lamport: 1),
  projectCreated("p2", "Learn Swift", on: "2026-10-14", lamport: 1),
  projectCreated("w1", "Launch", view: "work", on: "2026-10-12", lamport: 1),
]

private let monday = date("2026-10-19")

@Suite("When the next review of a project is worked out")
struct NextReviewReplayTests {
  @Test("a project is reviewed weekly unless told otherwise, counting from the day it was created")
  func aProjectIsReviewedWeekly() {
    let state = LibraryState.replay(projects)

    #expect(state.defaultReviewInterval == .every(days: 7))
    #expect(state.reviewInterval(of: TaskID("p1")) == .every(days: 7))
    #expect(state.nextReviewDate(of: TaskID("p1")) == date("2026-10-19"))
    #expect(state.nextReviewDate(of: TaskID("p2")) == date("2026-10-21"))
  }

  @Test("a project created before the day was kept is due for review at once")
  func aProjectWithoutADayIsDueAtOnce() {
    let state = LibraryState.replay([projectCreated("p1", "Old one", lamport: 1)])

    #expect(state.nextReviewDate(of: TaskID("p1")) == date("1970-01-08"))
    #expect(state.projectsDueForReview(in: .default, today: monday).map(\.project.id) == [TaskID("p1")])
  }

  @Test("reviewing sets the next review to the day reviewed plus the interval")
  func reviewingSetsTheNextReview() {
    let state = LibraryState.replay(projects + [projectReviewed("p1", on: "2026-10-20")])

    #expect(state.lastReviewDate(of: TaskID("p1")) == date("2026-10-20"))
    #expect(state.nextReviewDate(of: TaskID("p1")) == date("2026-10-27"))
  }

  @Test("reviewing again replaces the day")
  func reviewingAgainReplacesTheDay() {
    let events =
      projects + [projectReviewed("p1", on: "2026-10-20"), projectReviewed("p1", on: "2026-10-27", lamport: 4)]

    #expect(LibraryState.replay(events).nextReviewDate(of: TaskID("p1")) == date("2026-11-03"))
  }

  @Test("a chosen next review replaces the day worked out, and keeps the interval")
  func aChosenNextReviewReplacesTheDayWorkedOut() {
    let state = LibraryState.replay(projects + [reviewDateSet("p1", to: "2026-11-02")])

    #expect(state.nextReviewDate(of: TaskID("p1")) == date("2026-11-02"))
    #expect(state.nextReviewDate(of: TaskID("p2")) == date("2026-10-21"))
    #expect(state.reviewInterval(of: TaskID("p1")) == .every(days: 7))
  }

  @Test("choosing again replaces the day, in whichever order the events arrive")
  func choosingAgainReplacesTheDay() {
    let first = reviewDateSet("p1", to: "2026-11-02", lamport: 3)
    let second = reviewDateSet("p1", to: "2026-11-09", lamport: 4)

    #expect(LibraryState.replay(projects + [first, second]).nextReviewDate(of: TaskID("p1")) == date("2026-11-09"))
    #expect(LibraryState.replay(projects + [second, first]).nextReviewDate(of: TaskID("p1")) == date("2026-11-09"))
  }

  @Test("a chosen next review keeps a project out of the list until then")
  func aChosenNextReviewKeepsAProjectOutOfTheList() {
    let state = LibraryState.replay(projects + [reviewDateSet("p1", to: "2026-10-26")])

    #expect(state.projectsDueForReview(in: .default, today: monday).map(\.project.id) == [TaskID("p2")])
    #expect(
      state.projectsDueForReview(in: .default, today: date("2026-10-26")).map(\.project.id)
        == [TaskID("p1"), TaskID("p2")])
  }

  @Test("reviewing counts from the day reviewed again, and drops the chosen day")
  func reviewingDropsTheChosenDay() {
    let events =
      projects + [reviewDateSet("p1", to: "2026-11-30"), projectReviewed("p1", on: "2026-10-20", lamport: 4)]

    #expect(LibraryState.replay(events).nextReviewDate(of: TaskID("p1")) == date("2026-10-27"))
  }

  @Test("a day chosen after a review stands")
  func aDayChosenAfterAReviewStands() {
    let events =
      projects + [projectReviewed("p1", on: "2026-10-20"), reviewDateSet("p1", to: "2026-11-30", lamport: 4)]

    #expect(LibraryState.replay(events).nextReviewDate(of: TaskID("p1")) == date("2026-11-30"))
  }

  @Test("with review off a chosen day is not a next review")
  func withReviewOffAChosenDayIsNotANextReview() {
    let events = projects + [reviewDateSet("p1", to: "2026-11-02"), reviewIntervalSet("p1", to: .off, lamport: 4)]

    #expect(LibraryState.replay(events).nextReviewDate(of: TaskID("p1")) == nil)
  }

  @Test("a day chosen for a project that is not open is ignored")
  func aDayChosenForAProjectThatIsNotOpenIsIgnored() {
    let events = projects + [projectDropped("p1"), reviewDateSet("p1", to: "2026-11-02", lamport: 4)]
    let state = LibraryState.replay(events)

    #expect(state.nextReviewDate(of: TaskID("p1")) == nil)
  }

  @Test("the default interval is a number of days for all projects")
  func theDefaultIntervalIsANumberOfDays() {
    let state = LibraryState.replay(projects + [reviewDefaultSet(.every(days: 14))])

    #expect(state.defaultReviewInterval == .every(days: 14))
    #expect(state.nextReviewDate(of: TaskID("p1")) == date("2026-10-26"))
  }

  @Test("with the default off no project has a next review")
  func withTheDefaultOffNoProjectHasANextReview() {
    let state = LibraryState.replay(projects + [reviewDefaultSet(.off)])

    #expect(state.defaultReviewInterval == .off)
    #expect(state.nextReviewDate(of: TaskID("p1")) == nil)
    #expect(state.projectsDueForReview(in: .default, today: monday).isEmpty)
  }

  @Test("an interval of no days or fewer is review off", arguments: [0, -3])
  func noDaysIsOff(days: Int) {
    let state = LibraryState.replay(projects + [reviewDefaultSet(.every(days: days))])

    #expect(state.defaultReviewInterval == .off)
  }

  @Test("a project's own interval beats the default, and clearing it falls back")
  func aProjectsOwnIntervalBeatsTheDefault() {
    let own = projects + [reviewIntervalSet("p1", to: .every(days: 2))]
    let cleared = own + [reviewIntervalSet("p1", to: nil, lamport: 3)]

    #expect(LibraryState.replay(own).nextReviewDate(of: TaskID("p1")) == date("2026-10-14"))
    #expect(LibraryState.replay(own).reviewOverride(of: TaskID("p1")) == .every(days: 2))
    #expect(LibraryState.replay(own).nextReviewDate(of: TaskID("p2")) == date("2026-10-21"))
    #expect(LibraryState.replay(cleared).reviewOverride(of: TaskID("p1")) == nil)
    #expect(LibraryState.replay(cleared).nextReviewDate(of: TaskID("p1")) == date("2026-10-19"))
  }

  @Test("a project can be off while the default is on, and on while the default is off")
  func aProjectCanDifferFromTheDefault() {
    let off = LibraryState.replay(projects + [reviewIntervalSet("p1", to: .off)])
    let enabled = LibraryState.replay(
      projects + [reviewDefaultSet(.off), reviewIntervalSet("p1", to: .every(days: 3))])

    #expect(off.reviewInterval(of: TaskID("p1")) == .off)
    #expect(off.nextReviewDate(of: TaskID("p1")) == nil)
    #expect(off.nextReviewDate(of: TaskID("p2")) == date("2026-10-21"))
    #expect(enabled.nextReviewDate(of: TaskID("p1")) == date("2026-10-15"))
    #expect(enabled.nextReviewDate(of: TaskID("p2")) == nil)
  }

  @Test("an interval set for a project that is not active is ignored")
  func anIntervalForAProjectThatIsNotActiveIsIgnored() {
    let state = LibraryState.replay(projects + [reviewIntervalSet("ghost", to: .every(days: 2))])

    #expect(state.reviewOverride(of: TaskID("ghost")) == nil)
  }

  @Test("a project that is not active has no next review")
  func aProjectThatIsNotActiveHasNoNextReview() {
    let state = LibraryState.replay(projects + [projectCompleted("p1")])

    #expect(state.nextReviewDate(of: TaskID("p1")) == nil)
    #expect(state.nextReviewDate(of: TaskID("ghost")) == nil)
  }

  @Test("reviewing a project that is not active changes nothing")
  func reviewingAProjectThatIsNotActiveChangesNothing() {
    let state = LibraryState.replay(projects + [projectReviewed("ghost", on: "2026-10-20")])

    #expect(state.lastReviewDate(of: TaskID("ghost")) == nil)
  }

  @Test("the state is the same whatever order the events arrive in")
  func theStateIsTheSameInAnyOrder() {
    let events =
      projects + [
        projectReviewed("p1", on: "2026-10-20"), reviewDefaultSet(.every(days: 3)),
        reviewIntervalSet("p2", to: .off), projectDropped("p1"),
      ]

    #expect(LibraryState.replay(events) == LibraryState.replay(events.reversed()))
    #expect(LibraryState.replay(events) == LibraryState.replay(events + events))
  }
}

@Suite("When the review list is worked out")
struct ProjectReviewListReplayTests {
  @Test("it holds the projects whose next review is today or has passed, oldest first")
  func itHoldsTheProjectsDue() {
    let state = LibraryState.replay(projects)

    let list = state.projectsDueForReview(in: .default, today: date("2026-10-20"))
    #expect(list.map(\.project.id) == [TaskID("p1")])
    #expect(list.map(\.nextReview) == [date("2026-10-19")])
    #expect(state.projectsDueForReview(in: .default, today: date("2026-10-18")).isEmpty)
    #expect(
      state.projectsDueForReview(in: .default, today: date("2026-10-22")).map(\.project.id)
        == [TaskID("p1"), TaskID("p2")])
  }

  @Test("the project with the earlier review comes first, whatever the order they were created in")
  func theEarlierReviewComesFirst() {
    let state = LibraryState.replay(projects + [projectReviewed("p1", on: "2026-10-21")])

    let list = state.projectsDueForReview(in: .default, today: date("2026-10-29"))

    #expect(list.map(\.project.id) == [TaskID("p2"), TaskID("p1")])
  }

  @Test("projects due the same day come in the order they were created")
  func projectsDueTheSameDayComeInCreationOrder() {
    let events = [
      projectCreated("a", "Alpha", on: "2026-10-12", lamport: 1),
      projectCreated("b", "Bravo", on: "2026-10-12", lamport: 2),
      projectCreated("c", "Charlie", on: "2026-10-12", lamport: 3),
    ]

    let list = LibraryState.replay(events).projectsDueForReview(in: .default, today: monday)

    #expect(list.map(\.project.title) == ["Alpha", "Bravo", "Charlie"])
  }

  @Test("it holds the projects of the view asked about, and none of another")
  func itHoldsTheProjectsOfOneView() {
    let state = LibraryState.replay(projects)

    #expect(state.projectsDueForReview(in: .default, today: monday).map(\.project.id) == [TaskID("p1")])
    #expect(state.projectsDueForReview(in: ViewID("work"), today: monday).map(\.project.id) == [TaskID("w1")])
    #expect(state.projectsDueForReview(in: ViewID("nowhere"), today: monday).isEmpty)
  }

  @Test("sub-projects are reviewed too, and a completed project is not")
  func subProjectsAreReviewedAndCompletedOnesAreNot() {
    let events = [
      projectCreated("p1", "Move house", on: "2026-10-12", lamport: 1),
      projectCreated("p2", "Pack", under: "p1", on: "2026-10-12", lamport: 2),
      projectCreated("p3", "Done one", on: "2026-10-12", lamport: 3), projectCompleted("p3", lamport: 4),
    ]

    let list = LibraryState.replay(events).projectsDueForReview(in: .default, today: monday)

    #expect(list.map(\.project.id) == [TaskID("p1"), TaskID("p2")])
  }
}

@Suite("When a project is dropped")
struct ProjectStatusReplayTests {
  @Test("a dropped project leaves the open projects and is listed as dropped")
  func aDroppedProjectIsListedAsDropped() {
    let view = LibraryState.replay(projects + [projectDropped("p2")]).view(.default)

    #expect(view.projects.map(\.id) == [TaskID("p1")])
    #expect(view.completedProjects.map(\.item.id) == [TaskID("p2")])
    #expect(view.completedProjects.map(\.isDropped) == [true])
  }

  @Test("a drop event for a project that is not open changes nothing")
  func aDropEventForAProjectThatIsNotOpenChangesNothing() {
    let state = LibraryState.replay(projects + [projectDropped("ghost")])

    #expect(state.view(.default).projects.map(\.id) == [TaskID("p1"), TaskID("p2")])
    #expect(state.view(.default).completedProjects.isEmpty)
  }

  @Test("a dropped project hands out no next actions, nor do its sub-projects")
  func aDroppedProjectHandsOutNoNextActions() {
    let events = [
      projectCreated("p1", "Move house", lamport: 1), projectCreated("p2", "Pack", under: "p1", lamport: 1),
      projectCreated("p3", "Learn Swift", lamport: 1),
      captured("t1", "pack boxes", lamport: 1), moved("t1", to: "p2", lamport: 2),
      captured("t2", "book a van", lamport: 1), moved("t2", to: "p1", lamport: 2),
      captured("t3", "read a book", lamport: 1), moved("t3", to: "p3", lamport: 2),
    ]

    let active = LibraryState.replay(events).view(.default)
    let dropped = LibraryState.replay(events + [projectDropped("p1")]).view(.default)

    #expect(Set(active.nextActions.map(\.id)) == [TaskID("t1"), TaskID("t2"), TaskID("t3")])
    #expect(dropped.nextActions.map(\.id) == [TaskID("t3")])
  }

  @Test("a dropped sub-project hands out nothing while its parent still does")
  func aDroppedSubProjectHandsOutNothing() {
    let events = [
      projectCreated("p1", "Move house", lamport: 1), projectCreated("p2", "Pack", under: "p1", lamport: 1),
      captured("t1", "pack boxes", lamport: 1), moved("t1", to: "p2", lamport: 2),
      captured("t2", "book a van", lamport: 1), moved("t2", to: "p1", lamport: 2),
      projectDropped("p2"),
    ]

    let view = LibraryState.replay(events).view(.default)

    #expect(view.nextActions.map(\.id) == [TaskID("t2")])
  }

  @Test("dropping a project drops the tasks and sub-projects open in it")
  func droppingAProjectDropsWhatIsOpenInIt() {
    let events = [
      projectCreated("p1", "Move house", lamport: 1), projectCreated("p2", "Pack", under: "p1", lamport: 1),
      captured("t1", "pack boxes", lamport: 1), moved("t1", to: "p2", lamport: 2),
      captured("t2", "book a van", lamport: 1), moved("t2", to: "p1", lamport: 2),
      projectDropped("p1"),
    ]

    let view = LibraryState.replay(events).view(.default)

    #expect(view.openTasks.isEmpty)
    #expect(view.projects.isEmpty)
    #expect(view.completedTasks.map(\.item.id) == [TaskID("t1"), TaskID("t2")])
    #expect(view.completedTasks.map(\.isDropped) == [true, true])
    #expect(view.completedTasks.map(\.completedWith) == [TaskID("p1"), TaskID("p1")])
  }

  @Test("a dropped project's tasks are not candidates for Today")
  func aDroppedProjectsTasksAreNotCandidates() {
    let events = [
      projectCreated("p1", "Move house", lamport: 1),
      captured("t1", "pack boxes", lamport: 1), moved("t1", to: "p1", lamport: 2),
    ]
    func candidates(_ more: [EventEnvelope]) -> [TaskID] {
      LibraryState.replay(events + more).plan(for: .default, on: monday, today: monday).candidates.map(\.task.id)
    }

    #expect(candidates([]) == [TaskID("t1")])
    #expect(candidates([projectDropped("p1")]).isEmpty)
  }

  @Test("a dropped project is not reviewed and its review days are ignored")
  func aDroppedProjectIsNotReviewed() {
    let dropped = projects + [projectDropped("p1")]

    let state = LibraryState.replay(dropped + [projectReviewed("p1", on: "2026-10-20", lamport: 4)])

    #expect(state.nextReviewDate(of: TaskID("p1")) == nil)
    #expect(state.lastReviewDate(of: TaskID("p1")) == nil)
    #expect(state.projectsDueForReview(in: .default, today: monday).isEmpty)
  }

  @Test("reopening a dropped project brings back what its drop took along")
  func reopeningADroppedProjectBringsBackWhatItTook() {
    let events =
      projects + [
        captured("t1", "pack boxes", lamport: 3), moved("t1", to: "p1", lamport: 4), projectDropped("p1", lamport: 5),
        projectReopened("p1", lamport: 6),
      ]

    let view = LibraryState.replay(events).view(.default)

    #expect(view.projects.map(\.id) == [TaskID("p1"), TaskID("p2")])
    #expect(view.openTasks.map(\.id) == [TaskID("t1")])
    #expect(view.completedProjects.isEmpty)
    #expect(view.completedTasks.isEmpty)
  }
}
