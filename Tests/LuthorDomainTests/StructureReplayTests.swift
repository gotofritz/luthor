import LuthorDomain
import LuthorTestSupport
import Testing

private let weekly = RepeatRule(every: 1, unit: .week)

/// A weekly task in a project with a priority, an estimate, notes, a tag, a hard deadline, a day it is planned
/// for and a delegation: everything a copy does or does not carry. The lamport counter is 4.
private let routine: [EventEnvelope] = [
  projectCreated("p1", "Home", lamport: 1),
  captured("t1", "water plants", lamport: 1),
  moved("t1", to: "p1", lamport: 2),
  prioritized("t1", as: .important, lamport: 2),
  estimated("t1", as: 15, lamport: 2),
  noted("t1", "front room first", lamport: 2),
  tagCreated("g1", "home", lamport: 2),
  tagged("t1", with: "g1", lamport: 3),
  dueSet("t1", on: "2026-10-19", lamport: 3),
  repeatSet("t1", weekly, lamport: 3),
  scheduled("t1", on: "2026-10-19", lamport: 3),
  delegated("t1", to: "Sam", lamport: 4),
]

@Suite("When a task is duplicated")
struct DuplicateReplayTests {
  @Test("the copy is an open task in the same project with the same title, notes, priority and estimate")
  func theCopyHasTheSameCard() throws {
    let state = LibraryState.replay(routine + [duplicated("t1", as: "t2", on: "2026-10-20")])

    let view = state.view(.default)
    let copy = try #require(view.openTasks.first { $0.id == TaskID("t2") })
    #expect(copy.title == "water plants")
    #expect(copy.notes == "front room first")
    #expect(copy.priority == .important)
    #expect(copy.estimate == 15)
    #expect(copy.parentID == TaskID("p1"))
    #expect(copy.createdOn == date("2026-10-20"))
    #expect(view.projects.first?.tasks.map(\.id) == [TaskID("t1"), TaskID("t2")])
  }

  @Test("the copy has the due date, the tags and the repeat, but not the day planned or the delegation")
  func theCopyHasWhatTheNextOccurrenceHas() {
    let state = LibraryState.replay(routine + [duplicated("t1", as: "t2")])

    #expect(state.dueDate(of: TaskID("t2")) == DueDate(date: date("2026-10-19"), isHard: true))
    #expect(state.tags(of: TaskID("t2")).map(\.name) == ["home"])
    #expect(state.repeatRule(of: TaskID("t2")) == weekly)
    #expect(state.delegation(of: TaskID("t2")) == nil)
  }

  @Test("the copy is planned for no day, and the original keeps its day")
  func theCopyIsNotPlanned() {
    let state = LibraryState.replay([
      captured("t1", "water plants", lamport: 1), scheduled("t1", on: "2026-10-19", lamport: 2),
      duplicated("t1", as: "t2"),
    ])

    #expect(state.scheduledDate(of: TaskID("t1")) == date("2026-10-19"))
    #expect(state.scheduledDate(of: TaskID("t2")) == nil)
  }

  @Test("the original keeps everything it had")
  func theOriginalIsUntouched() {
    let before = LibraryState.replay(routine)
    let after = LibraryState.replay(routine + [duplicated("t1", as: "t2")])

    #expect(after.view(.default).openTasks.first { $0.id == TaskID("t1") } == before.view(.default).openTasks.first)
    #expect(after.delegation(of: TaskID("t1"))?.person == "Sam")
    #expect(after.tags(of: TaskID("t1")).map(\.name) == ["home"])
  }

  @Test("a completed task can be copied, and the copy is open")
  func aCompletedTaskCanBeCopied() {
    let state = LibraryState.replay([
      captured("t1", "pay tax", lamport: 1), completed("t1", lamport: 2), duplicated("t1", as: "t2"),
    ])

    #expect(state.view(.default).openTasks.map(\.id) == [TaskID("t2")])
    #expect(state.view(.default).completedTasks.map(\.item.id) == [TaskID("t1")])
  }

  @Test("a task that does not exist is ignored, and so is a copy that exists already")
  func aMissingSourceAndAnExistingCopyAreIgnored() {
    let state = LibraryState.replay([
      captured("t1", "pay tax", lamport: 1), captured("t2", "call bank", lamport: 1),
      duplicated("ghost", as: "t3"), duplicated("t1", as: "t2"),
    ])

    #expect(state.view(.default).openTasks.map(\.title) == ["pay tax", "call bank"])
  }

  @Test("the same event twice makes one copy")
  func theSameEventTwiceMakesOneCopy() {
    let event = duplicated("t1", as: "t2")
    let state = LibraryState.replay(routine + [event, event])

    #expect(state.view(.default).openTasks.count == 2)
  }
}

@Suite("When a task is deleted")
struct DeleteTaskReplayTests {
  @Test("an open task leaves the project and every other list, with everything that was set on it")
  func anOpenTaskIsForgottenWithItsData() {
    let state = LibraryState.replay(routine + [taskDeleted("t1", lamport: 5)])

    let view = state.view(.default)
    #expect(view.openTasks.isEmpty)
    #expect(view.projects.first?.children.isEmpty == true)
    #expect(state.dueDate(of: TaskID("t1")) == nil)
    #expect(state.tags(of: TaskID("t1")).isEmpty)
    #expect(state.repeatRule(of: TaskID("t1")) == nil)
    #expect(state.scheduledDate(of: TaskID("t1")) == nil)
    #expect(state.delegation(of: TaskID("t1")) == nil)
  }

  @Test("a completed task is deleted too")
  func aCompletedTaskIsDeleted() {
    let state = LibraryState.replay([
      captured("t1", "pay tax", lamport: 1), completed("t1", lamport: 2), taskDeleted("t1", lamport: 3),
    ])

    #expect(state.view(.default).completedTasks.isEmpty)
  }

  @Test("a deleted task is not brought back by capturing it again, by reopening, or by an event after it")
  func aDeletedTaskStaysDeleted() {
    let state = LibraryState.replay([
      captured("t1", "pay tax", lamport: 1), completed("t1", lamport: 2), taskDeleted("t1", lamport: 3),
      captured("t1", "pay tax", id: "again", lamport: 4), reopened("t1", lamport: 5),
      prioritized("t1", as: .critical, lamport: 6),
    ])

    #expect(state.view(.default).openTasks.isEmpty)
    #expect(state.view(.default).completedTasks.isEmpty)
  }

  @Test("other tasks are left alone, and a task that does not exist is ignored")
  func otherTasksAreLeftAlone() {
    let state = LibraryState.replay([
      captured("t1", "pay tax", lamport: 1), captured("t2", "call bank", lamport: 1),
      taskDeleted("t1", lamport: 2), taskDeleted("ghost", lamport: 3),
    ])

    #expect(state.view(.default).openTasks.map(\.id) == [TaskID("t2")])
  }
}

/// Holiday holds "book flights" and the sub-project Packing with "passport" and a completed "pack"; Garden
/// is a separate project with "water" in it.
private let holiday: [EventEnvelope] = [
  projectCreated("p1", "Holiday", lamport: 1),
  projectCreated("p2", "Packing", under: "p1", lamport: 2),
  projectCreated("p3", "Garden", lamport: 3),
  captured("t1", "book flights", lamport: 4), moved("t1", to: "p1", lamport: 5),
  captured("t2", "passport", lamport: 6), moved("t2", to: "p2", lamport: 7),
  captured("t3", "pack", lamport: 8), moved("t3", to: "p2", lamport: 9), completed("t3", lamport: 10),
  captured("t4", "water", lamport: 11), moved("t4", to: "p3", lamport: 12),
]

@Suite("When a project is deleted")
struct DeleteProjectReplayTests {
  @Test("it goes with its sub-projects and every task in them, open or completed")
  func itGoesWithEverythingInIt() {
    let state = LibraryState.replay(holiday + [projectDeleted("p1", lamport: 13)])

    let view = state.view(.default)
    #expect(view.projects.map(\.id) == [TaskID("p3")])
    #expect(view.openTasks.map(\.id) == [TaskID("t4")])
    #expect(view.completedTasks.isEmpty)
    #expect(view.completedProjects.isEmpty)
  }

  @Test("a sub-project leaves its parent's children")
  func aSubprojectLeavesItsParent() {
    let state = LibraryState.replay(holiday + [projectDeleted("p2", lamport: 13)])

    let view = state.view(.default)
    #expect(view.projects.map(\.id) == [TaskID("p1"), TaskID("p3")])
    #expect(view.projects.first?.children == [.task(view.openTasks[0])])
    #expect(view.openTasks.map(\.id) == [TaskID("t1"), TaskID("t4")])
    #expect(view.completedTasks.isEmpty)
  }

  @Test("a completed project goes with what its completion took along")
  func aCompletedProjectGoesWithWhatItTookAlong() {
    let state = LibraryState.replay(
      holiday + [projectCompleted("p1", lamport: 13), projectDeleted("p1", lamport: 14)])

    let view = state.view(.default)
    #expect(view.completedProjects.isEmpty)
    #expect(view.completedTasks.isEmpty)
    #expect(view.projects.map(\.id) == [TaskID("p3")])
  }

  @Test("a project completed on its own inside a project that is deleted goes too")
  func aCompletedSubprojectGoesWithItsParent() {
    let state = LibraryState.replay(
      holiday + [projectCompleted("p2", lamport: 13), projectDeleted("p1", lamport: 14)])

    #expect(state.view(.default).completedProjects.isEmpty)
    #expect(state.view(.default).completedTasks.isEmpty)
  }

  @Test("a dropped project can be deleted")
  func aDroppedProjectCanBeDeleted() {
    let state = LibraryState.replay(
      holiday + [projectDropped("p3", lamport: 13), projectDeleted("p3", lamport: 14)])

    #expect(state.view(.default).projects.map(\.id) == [TaskID("p1"), TaskID("p2")])
  }

  @Test("a project that does not exist is ignored, and a deleted one is not recreated")
  func aMissingProjectIsIgnored() {
    let state = LibraryState.replay(
      holiday + [projectDeleted("ghost", lamport: 13), projectDeleted("p3", lamport: 14)])

    #expect(state.view(.default).projects.map(\.id) == [TaskID("p1"), TaskID("p2")])
  }
}

@Suite("When a task is made into a project")
struct PromoteReplayTests {
  @Test("it stays the same item, now a parallel project with its title, notes, view and day created")
  func theTaskBecomesAProject() throws {
    let state = LibraryState.replay([
      viewCreated("v1", "Work", lamport: 1),
      captured("t1", "plan trip", view: "v1", on: "2026-10-17", lamport: 2), noted("t1", "in spring", lamport: 3),
      promoted("t1", lamport: 4),
    ])

    let view = state.view(ViewID("v1"))
    let project = try #require(view.projects.first)
    #expect(project.id == TaskID("t1"))
    #expect(project.title == "plan trip")
    #expect(project.notes == "in spring")
    #expect(project.kind == .parallel)
    #expect(project.createdOn == date("2026-10-17"))
    #expect(project.parentID == nil)
    #expect(view.openTasks.isEmpty)
    #expect(state.view(.default).projects.isEmpty)
  }

  @Test("a task filed in a project becomes a sub-project at the place it had")
  func aFiledTaskBecomesASubproject() {
    let state = LibraryState.replay([
      projectCreated("p0", "Holiday", lamport: 1),
      captured("t1", "book flights", lamport: 2), moved("t1", to: "p0", lamport: 3),
      captured("t2", "pack", lamport: 4), moved("t2", to: "p0", lamport: 5),
      promoted("t1", lamport: 6),
    ])

    let view = state.view(.default)
    #expect(view.projects.first { $0.id == TaskID("t1") }?.parentID == TaskID("p0"))
    #expect(view.projects.first { $0.id == TaskID("p0") }?.children.first == .project(TaskID("t1")))
    #expect(view.subprojects(of: TaskID("p0")).map(\.title) == ["book flights"])
    #expect(view.openTasks.map(\.id) == [TaskID("t2")])
  }

  @Test("what was set on the task stays with the item, though a project does not list it as a task")
  func whatWasSetOnTheTaskStays() {
    let state = LibraryState.replay(routine + [promoted("t1", lamport: 5)])

    #expect(state.view(.default).openTasks.isEmpty)
    #expect(state.dueDate(of: TaskID("t1")) == DueDate(date: date("2026-10-19"), isHard: true))
    #expect(state.tags(of: TaskID("t1")).map(\.name) == ["home"])
    #expect(state.repeatRule(of: TaskID("t1")) == weekly)
  }

  @Test("tasks can then be filed into it")
  func tasksCanBeFiledIntoIt() {
    let state = LibraryState.replay([
      captured("t1", "plan trip", lamport: 1), promoted("t1", lamport: 2),
      captured("t2", "book flights", lamport: 3), moved("t2", to: "t1", lamport: 4),
    ])

    #expect(state.view(.default).projects.first?.tasks.map(\.title) == ["book flights"])
  }

  @Test("a task that is not open, or does not exist, is ignored")
  func missingTasksAreIgnored() {
    let state = LibraryState.replay([
      projectCreated("p1", "Holiday", lamport: 1),
      captured("t1", "pay tax", lamport: 2), completed("t1", lamport: 3),
      captured("t2", "call bank", lamport: 4),
      promoted("t1", lamport: 5), promoted("ghost", lamport: 6),
    ])

    #expect(state.view(.default).projects.map(\.title) == ["Holiday"])
    #expect(state.view(.default).openTasks.map(\.id) == [TaskID("t2")])
  }
}

@Suite("When a project is made into a task")
struct DemoteReplayTests {
  private let nested: [EventEnvelope] = [
    projectCreated("p1", "Holiday", lamport: 1),
    projectCreated("p2", "Pack", under: "p1", lamport: 2),
    prioritized("p2", as: .important, lamport: 3),
    noted("p2", "check weight", lamport: 3),
  ]

  @Test("it is a task in its parent again, with what was set on it")
  func itIsATaskInItsParent() throws {
    let view = LibraryState.replay(nested + [demoted("p2", lamport: 4)]).view(.default)

    #expect(view.projects.map(\.id) == [TaskID("p1")])
    let task = try #require(view.projects.first?.tasks.first)
    #expect(task.id == TaskID("p2"))
    #expect(task.title == "Pack")
    #expect(task.priority == .important)
    #expect(task.notes == "check weight")
    #expect(task.kind == nil)
  }

  @Test("tasks can be made into a project again, and a project into a task again")
  func itCanGoBackAndForth() {
    let state = LibraryState.replay(nested + [demoted("p2", lamport: 4), promoted("p2", lamport: 5)])

    #expect(state.view(.default).projects.map(\.id) == [TaskID("p1"), TaskID("p2")])
  }

  @Test("a top-level one is a task with no parent")
  func aTopLevelOneHasNoParent() {
    let view = LibraryState.replay(nested + [demoted("p1", lamport: 4)]).view(.default)

    #expect(view.openTasks.map(\.id) == [TaskID("p1")])
    #expect(view.openTasks.first?.parentID == nil)
  }
}
