import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let editLog = [
  projectCreated("p1", "Holiday", kind: .parallel, on: "2026-10-01", lamport: 1),
  captured("t1", "book flights", on: "2026-10-02", lamport: 2), moved("t1", to: "p1", lamport: 3),
  captured("t2", "buy milk", lamport: 4),
]

@MainActor
private func makeLibrary(_ events: [EventEnvelope] = editLog) -> (LibraryViewModel, InMemoryEventLog) {
  let log = InMemoryEventLog(events)
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()), today: { date("2026-10-19") })
  library.reload()
  return (library, log)
}

@MainActor
@Suite("When a task card is shown")
struct TaskCardEditModeTests {
  @Test("it is read-only until Edit is pressed")
  func readOnlyByDefault() {
    let (library, _) = makeLibrary()
    library.selection = TaskID("t2")

    #expect(library.editingCard == nil)
  }

  @Test("Edit puts it into edit mode")
  func editEntersEditMode() {
    let (library, _) = makeLibrary()
    library.selection = TaskID("t2")

    library.editCard(.task(TaskID("t2")))

    #expect(library.editingCard == .task(TaskID("t2")))
  }

  @Test("Cancel leaves edit mode and writes nothing")
  func cancelWritesNothing() {
    let (library, log) = makeLibrary()
    library.selection = TaskID("t2")
    library.editCard(.task(TaskID("t2")))

    library.cancelCardEdit()

    #expect(library.editingCard == nil)
    #expect(log.events == editLog)
  }

  @Test("OK keeps the title, priority, estimate and notes, and leaves edit mode")
  func okKeepsEverything() {
    let (library, _) = makeLibrary()
    library.open(.project(TaskID("p1")))
    library.selection = TaskID("t1")
    library.editCard(.task(TaskID("t1")))

    library.saveCard(
      ofTask: TaskID("t1"),
      TaskCardDraft(title: "book trains", priority: .critical, estimate: 15, due: nil, notes: "not planes"))

    #expect(library.editingCard == nil)
    #expect(
      library.selectedTask
        == item(
          "t1", "book trains", in: "p1", priority: .critical, estimate: 15, notes: "not planes",
          createdOn: "2026-10-02"))
  }

  @Test("OK with nothing changed writes nothing")
  func okWithoutChangesWritesNothing() {
    let (library, log) = makeLibrary()
    library.selection = TaskID("t2")
    library.editCard(.task(TaskID("t2")))

    library.saveCard(
      ofTask: TaskID("t2"), TaskCardDraft(title: "buy milk", priority: nil, estimate: nil, due: nil, notes: ""))

    #expect(library.editingCard == nil)
    #expect(log.events == editLog)
  }

  @Test("OK keeps the review interval and next review day it was given")
  func okKeepsTheReviewFields() {
    let (library, _) = makeLibrary()
    library.open(.project(TaskID("p1")))
    library.editCard(.project(TaskID("p1")))

    library.saveCard(
      ofProject: TaskID("p1"),
      TaskCardDraft(
        title: "Holiday", priority: nil, estimate: nil, due: nil, notes: "",
        review: ProjectReviewDraft(interval: .every(days: 14), nextReview: date("2026-11-02"))),
      kind: .parallel)

    #expect(library.reviewOverride(of: TaskID("p1")) == .every(days: 14))
    #expect(library.nextReviewDate(of: TaskID("p1")) == date("2026-11-02"))
  }

  @Test("OK with no next review day lets it follow the new interval")
  func okWithNoNextReviewDayFollowsTheInterval() {
    let (library, _) = makeLibrary()
    library.open(.project(TaskID("p1")))
    library.editCard(.project(TaskID("p1")))

    library.saveCard(
      ofProject: TaskID("p1"),
      TaskCardDraft(
        title: "Holiday", priority: nil, estimate: nil, due: nil, notes: "",
        review: ProjectReviewDraft(interval: .every(days: 14), nextReview: nil)),
      kind: .parallel)

    #expect(library.nextReviewDate(of: TaskID("p1")) == date("2026-10-15"))
  }

  @Test("OK with no interval of its own goes back to the default")
  func okWithNoOwnIntervalGoesBackToTheDefault() {
    let (library, _) = makeLibrary(editLog + [reviewIntervalSet("p1", to: .every(days: 3), lamport: 5)])
    library.open(.project(TaskID("p1")))
    library.editCard(.project(TaskID("p1")))

    library.saveCard(
      ofProject: TaskID("p1"),
      TaskCardDraft(
        title: "Holiday", priority: nil, estimate: nil, due: nil, notes: "",
        review: ProjectReviewDraft(interval: nil, nextReview: nil)),
      kind: .parallel)

    #expect(library.reviewOverride(of: TaskID("p1")) == nil)
  }

  @Test("OK with a draft that says nothing about review leaves it as it was")
  func okWithoutReviewLeavesItAsItWas() {
    let events =
      editLog + [
        reviewIntervalSet("p1", to: .every(days: 3), lamport: 5), reviewDateSet("p1", to: "2026-11-02", lamport: 6),
      ]
    let (library, _) = makeLibrary(events)
    library.open(.project(TaskID("p1")))
    library.editCard(.project(TaskID("p1")))

    library.saveCard(
      ofProject: TaskID("p1"),
      TaskCardDraft(title: "Holiday", priority: nil, estimate: nil, due: nil, notes: ""), kind: .parallel)

    #expect(library.reviewOverride(of: TaskID("p1")) == .every(days: 3))
    #expect(library.nextReviewDate(of: TaskID("p1")) == date("2026-11-02"))
  }

  @Test("its estimate is its own if it has one, else the sum of its open tasks'")
  func theEstimateRollsUp() {
    let (library, _) = makeLibrary(editLog + [estimated("t1", as: 30, lamport: 5)])
    #expect(library.rolledUpEstimate(of: TaskID("p1")) == 30)

    library.estimate(TaskID("p1"), as: 90)

    #expect(library.rolledUpEstimate(of: TaskID("p1")) == 90)
  }

  @Test("OK with a blank title writes nothing and stays in edit mode")
  func blankTitleStaysInEditMode() {
    let (library, log) = makeLibrary()
    library.selection = TaskID("t2")
    library.editCard(.task(TaskID("t2")))

    library.saveCard(
      ofTask: TaskID("t2"), TaskCardDraft(title: "  ", priority: .critical, estimate: nil, due: nil, notes: ""))

    #expect(library.editingCard == .task(TaskID("t2")))
    #expect(log.events == editLog)
  }

  @Test("selecting another task leaves edit mode")
  func selectingAnotherTaskLeavesEditMode() {
    let (library, _) = makeLibrary()
    library.selection = TaskID("t2")
    library.editCard(.task(TaskID("t2")))

    library.selection = TaskID("t1")

    #expect(library.editingCard == nil)
  }

  @Test("so does showing another place")
  func showingAnotherPlaceLeavesEditMode() {
    let (library, _) = makeLibrary()
    library.selection = TaskID("t2")
    library.editCard(.task(TaskID("t2")))

    library.open(.project(TaskID("p1")))

    #expect(library.editingCard == nil)
  }

  @Test("the card of a completed task cannot be edited")
  func completedTaskStaysReadOnly() {
    let (library, _) = makeLibrary(editLog + [completed("t2", lamport: 5)])
    library.showCompleted = true
    library.selection = TaskID("t2")

    library.editCard(.task(TaskID("t2")))

    #expect(library.editingCard == nil)
  }

  @Test("a task captured today shows today as the day it was created")
  func capturedTaskHasTheDayItWasCreated() {
    let (library, _) = makeLibrary([])

    library.draft = "call bank"
    library.submit()

    #expect(library.tasks.map(\.createdOn) == [date("2026-10-19")])
  }
}

@MainActor
@Suite("When a project card is shown")
struct ProjectCardEditModeTests {
  @Test("Edit puts it into edit mode and Cancel leaves it, writing nothing")
  func editThenCancel() {
    let (library, log) = makeLibrary()
    library.open(.project(TaskID("p1")))

    library.editCard(.project(TaskID("p1")))
    #expect(library.editingCard == .project(TaskID("p1")))

    library.cancelCardEdit()
    #expect(library.editingCard == nil)
    #expect(log.events == editLog)
  }

  @Test("OK keeps the title, kind and notes, and leaves edit mode")
  func okKeepsEverything() {
    let (library, _) = makeLibrary()
    library.open(.project(TaskID("p1")))
    library.editCard(.project(TaskID("p1")))

    library.saveCard(
      ofProject: TaskID("p1"),
      TaskCardDraft(title: "Summer", priority: nil, estimate: nil, due: nil, notes: "deadline in June"),
      kind: .sequential)

    #expect(library.editingCard == nil)
    #expect(library.shownProject?.title == "Summer")
    #expect(library.shownProject?.kind == .sequential)
    #expect(library.shownProject?.notes == "deadline in June")
  }

  @Test("OK also keeps its priority, estimate, due date, repeat and tags, as for a task")
  func okKeepsTheTaskFields() throws {
    let (library, _) = makeLibrary()
    library.open(.project(TaskID("p1")))
    library.editCard(.project(TaskID("p1")))
    let due = DueDate(date: date("2027-04-01"), isHard: true)

    library.saveCard(
      ofProject: TaskID("p1"),
      TaskCardDraft(
        title: "Holiday", priority: .important, estimate: 120, due: due, notes: "", tags: ["travel"],
        repeatRule: RepeatRule(every: 1, unit: .year)),
      kind: .parallel)

    #expect(library.editingCard == nil)
    #expect(library.shownProject?.priority == .important)
    #expect(library.shownProject?.estimate == 120)
    #expect(library.dueDate(of: TaskID("p1")) == due)
    #expect(library.repeatRule(of: TaskID("p1")) == RepeatRule(every: 1, unit: .year))
    #expect(library.tagItems(of: TaskID("p1")).map(\.name) == ["travel"])
  }

  @Test("its estimate is its own if it has one, else the sum of its open tasks'")
  func theEstimateRollsUp() {
    let (library, _) = makeLibrary(editLog + [estimated("t1", as: 30, lamport: 5)])
    #expect(library.rolledUpEstimate(of: TaskID("p1")) == 30)

    library.estimate(TaskID("p1"), as: 90)

    #expect(library.rolledUpEstimate(of: TaskID("p1")) == 90)
  }

  @Test("OK with a blank title writes nothing and stays in edit mode")
  func blankTitleStaysInEditMode() {
    let (library, log) = makeLibrary()
    library.open(.project(TaskID("p1")))
    library.editCard(.project(TaskID("p1")))

    library.saveCard(
      ofProject: TaskID("p1"), TaskCardDraft(title: "", priority: nil, estimate: nil, due: nil, notes: "x"),
      kind: .sequential)

    #expect(library.editingCard == .project(TaskID("p1")))
    #expect(log.events == editLog)
  }

  @Test("opening another project leaves edit mode")
  func openingAnotherProjectLeavesEditMode() {
    let (library, _) = makeLibrary(editLog + [projectCreated("p2", "Taxes", lamport: 5)])
    library.open(.project(TaskID("p1")))
    library.editCard(.project(TaskID("p1")))

    library.open(.project(TaskID("p2")))

    #expect(library.editingCard == nil)
  }

  @Test("the card of a completed project cannot be edited")
  func completedProjectStaysReadOnly() {
    let (library, _) = makeLibrary(editLog + [projectCompleted("p1", lamport: 5)])
    library.showCompleted = true
    library.open(.project(TaskID("p1")))

    library.editCard(.project(TaskID("p1")))

    #expect(library.editingCard == nil)
  }

  @Test("a project created today shows today as the day it was created")
  func createdProjectHasTheDayItWasCreated() {
    let (library, _) = makeLibrary([])

    library.addProject(titled: "Taxes", kind: .parallel, under: nil)

    #expect(library.projects.map(\.createdOn) == [date("2026-10-19")])
  }
}

@MainActor
@Suite("When a field of a card is changed on the card itself")
struct CardFieldInPlaceTests {
  @Test("a task's priority, estimate and due date each take effect at once")
  func taskFieldsApplyAtOnce() {
    let (library, _) = makeLibrary()
    library.selection = TaskID("t2")

    library.prioritize(TaskID("t2"), as: .important)
    library.estimate(TaskID("t2"), as: 30)
    library.setDue(TaskID("t2"), to: date("2026-10-30"), isHard: false)

    #expect(library.selectedTask?.priority == .important)
    #expect(library.selectedTask?.estimate == 30)
    #expect(library.dueDate(of: TaskID("t2")) == DueDate(date: date("2026-10-30"), isHard: false))
  }

  @Test("setting the tags replaces the ones the task has")
  func tagsAreReplaced() {
    let (library, _) = makeLibrary()
    library.tagTask(TaskID("t2"), named: "home")

    library.setTags(TaskID("t2"), to: ["calls", "errands"])

    #expect(library.tagItems(of: TaskID("t2")).map(\.name).sorted() == ["calls", "errands"])
  }
}
