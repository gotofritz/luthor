import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// Garden holds "mow the lawn" and the sub-project Roses; "buy milk" is loose in the inbox.
private let gardenLog = [
  projectCreated("p1", "Garden", lamport: 1),
  captured("t1", "mow the lawn", under: "p1", lamport: 2),
  projectCreated("p2", "Roses", under: "p1", lamport: 3),
  captured("t2", "buy milk", lamport: 4),
]

@MainActor
@Suite("When the plus button of a column is pressed")
struct NewItemStartViewModelTests {
  @Test("a new project starts with no priority and no estimate")
  func aNewProjectHasNoDefaults() {
    let (library, _) = makeInbox(gardenLog)

    library.beginNewItem(under: TaskID("p1"), kind: .project(.parallel))

    #expect(library.newItem?.card.priority == nil)
    #expect(library.newItem?.card.estimate == nil)
  }

  @Test("a new task is being edited, seeded with priority optional and an estimate of 5 minutes")
  func aNewTaskIsSeededWithDefaults() {
    let (library, log) = makeInbox(gardenLog)

    library.beginNewItem(under: TaskID("p1"), kind: .task)

    #expect(library.newItem?.parentID == TaskID("p1"))
    #expect(library.newItem?.kind == .task)
    #expect(library.newItem?.card.title == "")
    #expect(library.newItem?.card.priority == .optional)
    #expect(library.newItem?.card.estimate == 5)
    #expect(log.events == gardenLog)
  }

  @Test("the columns end at that column, so the card of the new item is the next one")
  func theColumnsEndAtThatColumn() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p2")))
    #expect(library.columns.count == 3)

    library.beginNewItem(under: TaskID("p1"), kind: .task)

    #expect(library.path == [TaskID("p1")])
    #expect(library.columns.count == 2)
  }

  @Test("in the first column no project is shown")
  func inTheFirstColumnNoProjectIsShown() {
    let (library, _) = makeInbox(gardenLog)
    library.open(.project(TaskID("p1")))

    library.beginNewItem(under: nil, kind: .project(.parallel))

    #expect(library.path.isEmpty)
    #expect(library.columns.count == 1)
    #expect(library.newItem?.parentID == nil)
  }

  @Test("typing a title updates the title of the new item as it goes")
  func typingUpdatesTheTitle() {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)

    library.setNewItemTitle("pru")
    library.setNewItemTitle("prune")

    #expect(library.newItem?.card.title == "prune")
  }

  @Test("the kind of the new item can be changed")
  func theKindCanBeChanged() {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)

    library.setNewItemKind(.project(.sequential))

    #expect(library.newItem?.kind == .project(.sequential))
  }

  @Test("another press on the same column keeps what was typed")
  func anotherPressKeepsWhatWasTyped() {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)
    library.setNewItemTitle("prune")
    library.setNewItemKind(.project(.sequential))

    library.beginNewItem(under: TaskID("p1"), kind: .task)

    #expect(library.newItem?.card.title == "prune")
    #expect(library.newItem?.kind == .project(.sequential))
  }

  @Test("a press on another column starts a fresh item")
  func aPressOnAnotherColumnStartsAFreshItem() {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)
    library.setNewItemTitle("prune")

    library.beginNewItem(under: TaskID("p2"), kind: .task)

    #expect(library.newItem?.parentID == TaskID("p2"))
    #expect(library.newItem?.card.title == "")
  }
}

@MainActor
@Suite("When the kind of a new item is changed on its card")
struct NewItemKindSwitchViewModelTests {
  @Test("a project drops the defaults of a task")
  func aProjectDropsTheDefaults() {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)

    library.setNewItemKind(.project(.parallel))

    #expect(library.newItem?.card.priority == nil)
    #expect(library.newItem?.card.estimate == nil)
  }

  @Test("a task again brings the defaults back")
  func aTaskAgainBringsTheDefaultsBack() {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)
    library.setNewItemKind(.project(.sequential))

    library.setNewItemKind(.task)

    #expect(library.newItem?.card.priority == .optional)
    #expect(library.newItem?.card.estimate == 5)
  }

  @Test("a priority and an estimate the user set stay")
  func fieldsTheUserSetStay() {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)
    library.setNewItemPriority(.critical)
    library.setNewItemEstimate(30)

    library.setNewItemKind(.project(.parallel))
    #expect(library.newItem?.card.priority == .critical)
    #expect(library.newItem?.card.estimate == 30)

    library.setNewItemKind(.task)
    #expect(library.newItem?.card.priority == .critical)
    #expect(library.newItem?.card.estimate == 30)
  }

  @Test("a priority the user cleared stays cleared, and the estimate still follows the kind")
  func aClearedFieldStaysCleared() {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)
    library.setNewItemPriority(nil)

    library.setNewItemKind(.project(.parallel))
    library.setNewItemKind(.task)

    #expect(library.newItem?.card.priority == nil)
    #expect(library.newItem?.card.estimate == 5)
  }

  @Test("setting a field to what it already holds is not an edit")
  func settingTheSameValueIsNotAnEdit() {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)
    library.setNewItemPriority(.optional)
    library.setNewItemEstimate(5)

    library.setNewItemKind(.project(.parallel))

    #expect(library.newItem?.card.priority == nil)
    #expect(library.newItem?.card.estimate == nil)
  }
}

@MainActor
@Suite("When a new item is kept with OK")
struct NewItemSaveViewModelTests {
  @Test("a task is filed in the project with the card's fields, and selected")
  func aTaskIsFiledAndSelected() throws {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)
    library.setNewItemTitle("prune")
    let card = try #require(library.newItem?.card)

    library.saveNewItem(card)

    let prune = try #require(library.tasks.first { $0.title == "prune" })
    #expect(prune.parentID == TaskID("p1"))
    #expect(prune.priority == .optional)
    #expect(prune.estimate == 5)
    #expect(library.selection == prune.id)
    #expect(library.cardTarget == .task(prune.id))
    #expect(library.newItem == nil)
  }

  @Test("fields changed on the card win over the defaults")
  func changedFieldsWin() throws {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)
    var card = try #require(library.newItem?.card)
    card.title = "prune"
    card.priority = .critical
    card.estimate = 30
    card.notes = "before spring"

    library.saveNewItem(card)

    let prune = try #require(library.tasks.first { $0.title == "prune" })
    #expect(prune.priority == .critical)
    #expect(prune.estimate == 30)
    #expect(prune.notes == "before spring")
  }

  @Test("a task with no priority and no estimate keeps none")
  func clearedFieldsStayCleared() throws {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)
    var card = try #require(library.newItem?.card)
    card.title = "prune"
    card.priority = nil
    card.estimate = nil

    library.saveNewItem(card)

    let prune = try #require(library.tasks.first { $0.title == "prune" })
    #expect(prune.priority == nil)
    #expect(prune.estimate == nil)
  }

  @Test("a sequential project is made inside the project, with no priority and no estimate, and opened")
  func aProjectIsMadeAndOpened() throws {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .project(.sequential))
    library.setNewItemTitle("Herbs")
    let card = try #require(library.newItem?.card)

    library.saveNewItem(card)

    let herbs = try #require(library.projects.first { $0.title == "Herbs" })
    #expect(herbs.parentID == TaskID("p1"))
    #expect(herbs.kind == .sequential)
    #expect(herbs.priority == nil)
    #expect(herbs.estimate == nil)
    #expect(library.shownProject?.id == herbs.id)
    #expect(library.newItem == nil)
  }

  @Test("in the first column a project is made top-level")
  func inTheFirstColumnAProjectIsTopLevel() throws {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: nil, kind: .project(.parallel))
    library.setNewItemTitle("Taxes")
    let card = try #require(library.newItem?.card)

    library.saveNewItem(card)

    let taxes = try #require(library.projects.first { $0.title == "Taxes" })
    #expect(taxes.parentID == nil)
  }

  @Test("a blank title writes nothing and keeps the new item being edited")
  func aBlankTitleWritesNothing() throws {
    let (library, log) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)
    library.setNewItemTitle("   ")
    let card = try #require(library.newItem?.card)

    library.saveNewItem(card)

    #expect(log.events == gardenLog)
    #expect(library.newItem != nil)
  }
}

@MainActor
@Suite("When a new item is not kept")
struct NewItemDiscardViewModelTests {
  @Test("Cancel drops it and writes nothing")
  func cancelDropsIt() {
    let (library, log) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)
    library.setNewItemTitle("prune")

    library.cancelNewItem()

    #expect(library.newItem == nil)
    #expect(log.events == gardenLog)
  }

  @Test("picking another task drops it")
  func pickingATaskDropsIt() {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)

    library.selection = TaskID("t1")

    #expect(library.newItem == nil)
  }

  @Test("opening a project drops it")
  func openingAProjectDropsIt() {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)

    library.open(.project(TaskID("p2")))

    #expect(library.newItem == nil)
  }

  @Test("showing another place drops it")
  func showingAnotherPlaceDropsIt() {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)

    library.show(.today)

    #expect(library.newItem == nil)
  }

  @Test("clicking the empty part of a column drops it")
  func clickingTheEmptyPartDropsIt() {
    let (library, _) = makeInbox(gardenLog)
    library.beginNewItem(under: TaskID("p1"), kind: .task)

    library.deselectColumn(of: nil)

    #expect(library.newItem == nil)
  }
}

@MainActor
@Suite("When Add Tasks is pressed on a task")
struct AddTasksStartsNewItemViewModelTests {
  @Test("the task becomes a project and a new task is being edited in it, in one go")
  func theTaskBecomesAProjectWithANewTask() throws {
    let (library, _) = makeInbox(gardenLog)

    library.addTasks(to: TaskID("t2"))

    #expect(library.shownProject?.id == TaskID("t2"))
    #expect(library.newItem?.parentID == TaskID("t2"))
    #expect(library.newItem?.kind == .task)
    #expect(library.newItem?.card.priority == .optional)
    #expect(library.newItem?.card.estimate == 5)
  }

  @Test("OK files the new task in it")
  func okFilesTheTaskInIt() throws {
    let (library, _) = makeInbox(gardenLog)
    library.addTasks(to: TaskID("t2"))
    library.setNewItemTitle("oat milk")
    let card = try #require(library.newItem?.card)

    library.saveNewItem(card)

    #expect(library.shownProject?.tasks.map(\.title) == ["oat milk"])
  }

  @Test("a task that is no longer open starts no new item")
  func aClosedTaskStartsNothing() {
    let (library, _) = makeInbox(gardenLog + [completed("t2", lamport: 5)])

    library.addTasks(to: TaskID("t2"))

    #expect(library.newItem == nil)
  }
}
