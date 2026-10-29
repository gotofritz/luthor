import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let gardenLog = [
  projectCreated("p1", "Garden", lamport: 1),
  captured("t1", "mow the lawn", under: "p1", lamport: 2),
  projectCreated("p2", "Roses", under: "p1", lamport: 3),
]

@MainActor
@Suite("When a task is added from the plus button of a column")
struct ColumnAddTaskViewModelTests {
  @Test("it is filed in the project the column lists")
  func taskIsFiledInTheColumnsProject() {
    let (library, log) = makeInbox(gardenLog)

    library.addTask(titled: "prune", to: TaskID("p1"))

    #expect(log.events.last == captured("id-2", "prune", id: "id-1", on: "2026-10-19", under: "p1", lamport: 4))
  }

  @Test("with no project it goes to the inbox")
  func taskWithNoProjectGoesToTheInbox() {
    let (library, log) = makeInbox(gardenLog)

    library.addTask(titled: "buy milk", to: nil)

    #expect(log.events.last == captured("id-2", "buy milk", id: "id-1", on: "2026-10-19", lamport: 4))
    #expect(library.tasks.map(\.title) == ["buy milk"])
  }

  @Test("a blank title adds nothing")
  func blankTitleAddsNothing() {
    let (library, log) = makeInbox(gardenLog)

    library.addTask(titled: "  ", to: TaskID("p1"))

    #expect(log.events == gardenLog)
    #expect(library.errorMessage == nil)
  }
}

@MainActor
@Suite("When a project is added from the plus button of a column")
struct ColumnAddProjectViewModelTests {
  @Test("it is made inside the project the column lists")
  func projectIsMadeInTheColumnsProject() {
    let (library, log) = makeInbox(gardenLog)

    library.addProject(titled: "Herbs", kind: .sequential, under: TaskID("p1"))

    let created = projectCreated(
      "id-2", "Herbs", kind: .sequential, under: "p1", id: "id-1", on: "2026-10-19", lamport: 4)
    #expect(log.events.last == created)
  }

  @Test("in the first column it is top-level")
  func projectInTheFirstColumnIsTopLevel() {
    let (library, log) = makeInbox(gardenLog)

    library.addProject(titled: "Taxes", kind: .parallel, under: nil)

    #expect(log.events.last == projectCreated("id-2", "Taxes", id: "id-1", on: "2026-10-19", lamport: 4))
    #expect(library.columns.first?.entries.map(\.id) == ["project-p1", "project-id-2"])
  }

  @Test("a blank title adds nothing")
  func blankTitleAddsNothing() {
    let (library, log) = makeInbox(gardenLog)

    library.addProject(titled: "", kind: .parallel, under: nil)

    #expect(log.events == gardenLog)
    #expect(library.errorMessage == nil)
  }

  @Test("a failed write is reported")
  func failedWriteIsReported() {
    let (library, log) = makeInbox(gardenLog)
    log.appendFailure = .ioFailure("disk full")

    library.addProject(titled: "Herbs", kind: .parallel, under: nil)

    #expect(library.errorMessage == "disk full")
  }
}

@MainActor
@Suite("When a note is added on a card")
struct CardNoteViewModelTests {
  @Test("it becomes a bullet after the others, on a task")
  func noteFollowsTheOthersOnATask() {
    let (library, log) = makeInbox(gardenLog + [noted("t1", "front first", lamport: 4)])
    library.open(.project(TaskID("p1")))

    library.appendNote("then the back", to: TaskID("t1"))

    #expect(log.events.last == noted("t1", "front first\nthen the back", id: "id-1", lamport: 5))
    #expect(NoteBullets.bullets(in: library.tasks.first?.notes) == ["front first", "then the back"])
  }

  @Test("it becomes a bullet on a project too")
  func noteBecomesABulletOnAProject() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p1")))

    library.appendNote("order seeds", to: TaskID("p1"))

    #expect(NoteBullets.bullets(in: library.shownProject?.notes) == ["order seeds"])
  }

  @Test("a blank note adds nothing")
  func blankNoteAddsNothing() {
    let (library, log) = makeInbox(gardenLog)

    library.appendNote(" ", to: TaskID("t1"))

    #expect(log.events == gardenLog)
  }

  @Test("deleting a bullet leaves the others")
  func deletingABulletLeavesTheOthers() {
    let (library, log) = makeInbox(gardenLog + [noted("t1", "front\nback\nshed", lamport: 4)])
    library.open(.project(TaskID("p1")))

    library.deleteNote(at: 1, of: TaskID("t1"))

    #expect(log.events.last == noted("t1", "front\nshed", id: "id-1", lamport: 5))
    #expect(NoteBullets.bullets(in: library.tasks.first?.notes) == ["front", "shed"])
  }
}

@MainActor
@Suite("When the columns are browsed")
struct CardColumnViewModelTests {
  @Test("no card is shown while nothing is picked in the inbox")
  func noCardInTheInbox() {
    let (library, _) = makeInbox(gardenLog)

    #expect(library.cardTarget == nil)
  }

  @Test("a project that is opened lists its children and shows no card")
  func openedProjectShowsNoCard() {
    let (library, _) = makeInbox(gardenLog)

    library.open(.project(TaskID("p1")))

    #expect(library.cardTarget == nil)
    #expect(library.projectCardOpen == false)
  }

  @Test("a project lists its tasks before its sub-projects, whatever the order they were added in")
  func tasksComeBeforeSubProjects() {
    let (library, _) = makeInbox(gardenLog)

    library.open(.project(TaskID("p1")))

    #expect(library.columns.last?.entries.map(\.id) == ["task-t1", "project-p2"])
  }

  @Test("a task that is picked shows its card instead")
  func pickedTaskShowsItsCard() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p1")))

    library.selection = TaskID("t1")

    #expect(library.cardTarget == .task(TaskID("t1")))
  }

  @Test("opening the project again deselects the task and shows no card")
  func reopeningTheProjectDeselectsTheTask() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p1")))
    library.selection = TaskID("t1")

    library.open(.project(TaskID("p1")))

    #expect(library.selection == nil)
    #expect(library.cardTarget == nil)
  }

  @Test("opening a sub-project's parent closes the sub-project's column")
  func openingTheParentClosesTheSubprojectColumn() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p2")))

    library.open(.project(TaskID("p1")))

    #expect(library.columns.map(\.id) == ["top", "project-p1"])
    #expect(library.cardTarget == nil)
  }

  @Test("a task picked in the inbox shows its card")
  func inboxTaskShowsItsCard() {
    let (library, _) = makeInbox([captured("t9", "buy milk", lamport: 1)])

    library.selection = TaskID("t9")

    #expect(library.cardTarget == .task(TaskID("t9")))
  }

  @Test("deselecting in the first column closes every project")
  func deselectingTheFirstColumnClosesEveryProject() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p2")))

    library.deselectColumn(of: nil)

    #expect(library.columns.map(\.id) == ["top"])
    #expect(library.path == [])
    #expect(library.section == .projects)
    #expect(library.cardTarget == nil)
  }

  @Test("deselecting in a later column closes what lies beyond its project")
  func deselectingALaterColumnClosesTheColumnsBeyond() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p2")))

    library.deselectColumn(of: TaskID("p1"))

    #expect(library.columns.map(\.id) == ["top", "project-p1"])
    #expect(library.cardTarget == nil)
  }

  @Test("deselecting in the last column drops the task picked")
  func deselectingTheLastColumnDropsTheTask() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p1")))
    library.selection = TaskID("t1")

    library.deselectColumn(of: TaskID("p1"))

    #expect(library.selection == nil)
    #expect(library.cardTarget == nil)
  }
}

@MainActor
@Suite("When the pencil of a project row is pressed")
struct ProjectCardPencilViewModelTests {
  @Test("the project's card replaces its list of children")
  func cardReplacesTheChildren() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p1")))

    library.toggleProjectCard(TaskID("p1"))

    #expect(library.projectCardOpen)
    #expect(library.cardTarget == .project(TaskID("p1")))
  }

  @Test("on a project that is not open, it is opened first")
  func unopenedProjectIsOpenedFirst() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p2")))

    library.toggleProjectCard(TaskID("p1"))

    #expect(library.path == [TaskID("p1")])
    #expect(library.cardTarget == .project(TaskID("p1")))
  }

  @Test("pressing it again brings the list back")
  func pressingAgainClosesTheCard() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p1")))
    library.toggleProjectCard(TaskID("p1"))

    library.toggleProjectCard(TaskID("p1"))

    #expect(library.projectCardOpen == false)
    #expect(library.cardTarget == nil)
  }

  @Test("picking a task shows the task's card and closes the project's")
  func pickingATaskClosesTheProjectCard() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p1")))
    library.toggleProjectCard(TaskID("p1"))

    library.selection = TaskID("t1")

    #expect(library.projectCardOpen == false)
    #expect(library.cardTarget == .task(TaskID("t1")))
  }

  @Test("opening another project, or leaving the projects, closes the card")
  func navigatingClosesTheProjectCard() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p1")))
    library.toggleProjectCard(TaskID("p1"))

    library.open(.project(TaskID("p2")))
    #expect(library.projectCardOpen == false)

    library.toggleProjectCard(TaskID("p2"))
    library.show(.inbox)
    #expect(library.projectCardOpen == false)
  }

  @Test("starting a new item closes the project's card")
  func newItemClosesTheProjectCard() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p1")))
    library.toggleProjectCard(TaskID("p1"))

    library.beginNewItem(under: nil, kind: .project(.parallel))

    #expect(library.projectCardOpen == false)
  }
}

@MainActor
@Suite("When a note is edited on a card")
struct CardNoteEditViewModelTests {
  private let twoNotes = gardenLog + [noted("t1", "front first\nthen the back", lamport: 4)]

  @Test("the bullet takes the new text and the others stay")
  func bulletTakesTheNewText() {
    let (library, _) = makeInbox(twoNotes)
    library.open(.project(TaskID("p1")))

    library.editNote(at: 0, of: TaskID("t1"), to: "front lawn first")

    #expect(NoteBullets.bullets(in: library.tasks.first?.notes) == ["front lawn first", "then the back"])
  }

  @Test("a blank text deletes the bullet")
  func blankTextDeletesTheBullet() {
    let (library, _) = makeInbox(twoNotes)
    library.open(.project(TaskID("p1")))

    library.editNote(at: 1, of: TaskID("t1"), to: "  ")

    #expect(NoteBullets.bullets(in: library.tasks.first?.notes) == ["front first"])
  }

  @Test("the same text writes nothing")
  func sameTextWritesNothing() {
    let (library, log) = makeInbox(twoNotes)
    library.open(.project(TaskID("p1")))

    library.editNote(at: 0, of: TaskID("t1"), to: "front first")

    #expect(log.events == twoNotes)
  }
}
