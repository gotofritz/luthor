import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// "call bank" is critical, "pay rent" important, "tidy desk" optional, and "sort mail" has no priority.
private let priorityLog = [
  captured("t1", "call bank", lamport: 1), prioritized("t1", as: .critical, lamport: 2),
  captured("t2", "pay rent", lamport: 3), prioritized("t2", as: .important, lamport: 4),
  captured("t3", "tidy desk", lamport: 5), prioritized("t3", as: .optional, lamport: 6),
  captured("t4", "sort mail", lamport: 7),
]

@MainActor
@Suite("When priorities are picked in Prios")
struct PriorityGroupsViewModelTests {
  @Test("each picked priority has a list of its own, the most urgent first")
  func eachPickedPriorityHasAList() {
    let (library, _) = makeInbox(priorityLog)
    library.show(.priorities)

    library.selectPriorities([.optional, .critical])

    #expect(library.priorityGroups.map(\.priority) == [.critical, .optional])
    #expect(library.priorityGroups.map { $0.tasks.map(\.id.rawValue) } == [["t1"], ["t3"]])
  }

  @Test("a picked priority with no task has an empty list, which still takes new tasks")
  func anEmptyListStaysThere() {
    let (library, _) = makeInbox(priorityLog)
    library.show(.priorities)

    library.selectPriorities([.someday])

    #expect(library.priorityGroups.map(\.priority) == [.someday])
    #expect(library.priorityGroups.first?.tasks == [])
  }

  @Test("no priority is a list too, after the others")
  func noPriorityIsAListToo() {
    let (library, _) = makeInbox(priorityLog)
    library.show(.priorities)

    library.selectPriorities([nil, .important])

    #expect(library.priorityGroups.map(\.priority) == [.important, nil])
    #expect(library.priorityGroups.map { $0.tasks.map(\.id.rawValue) } == [["t2"], ["t4"]])
  }

  @Test("with none picked there is no list")
  func nonePickedNoList() {
    let (library, _) = makeInbox(priorityLog)
    library.show(.priorities)

    #expect(library.priorityGroups.isEmpty)
  }

  @Test("the lists hold the same tasks as the list of tasks does")
  func theListsHoldTheTasksShown() {
    let (library, _) = makeInbox(priorityLog)
    library.show(.priorities)

    library.selectPriorities([.critical, .important, .optional, nil])

    #expect(library.priorityGroups.flatMap(\.tasks) == library.tasks)
  }
}

@MainActor
@Suite("When Add Tasks is pressed at the bottom of a priority's list")
struct AddTaskWithPriorityViewModelTests {
  @Test("a new task is being edited with that priority, and nothing is written yet")
  func aNewTaskHasThePriority() {
    let (library, log) = makeInbox(priorityLog)
    library.show(.priorities)
    library.selectPriorities([.critical, .optional])

    library.addTask(withPriority: .optional)

    #expect(library.newItem?.kind == .task)
    #expect(library.newItem?.parentID == nil)
    #expect(library.newItem?.card.priority == .optional)
    #expect(library.newItem?.card.estimate == nil)
    #expect(log.events == priorityLog)
  }

  @Test("the list of no priority starts a task with none")
  func noPriorityStartsATaskWithNone() {
    let (library, _) = makeInbox(priorityLog)
    library.show(.priorities)
    library.selectPriorities([nil])

    library.addTask(withPriority: nil)

    #expect(library.newItem?.card.priority == nil)
  }

  @Test("another list's button starts a new task, dropping the one begun")
  func anotherListStartsAnother() {
    let (library, _) = makeInbox(priorityLog)
    library.show(.priorities)
    library.selectPriorities([.critical, .optional])
    library.addTask(withPriority: .critical)
    library.setNewItemTitle("half typed")

    library.addTask(withPriority: .optional)

    #expect(library.newItem?.card.title == "")
    #expect(library.newItem?.card.priority == .optional)
  }

  @Test("each task begun is a new item, so its card starts afresh")
  func eachTaskBegunIsNew() throws {
    let (library, _) = makeInbox(priorityLog)
    library.show(.priorities)
    library.selectPriorities([.critical, .optional])
    library.addTask(withPriority: .critical)
    let first = try #require(library.newItem?.number)

    library.addTask(withPriority: .optional)

    #expect(try #require(library.newItem?.number) != first)
  }

  @Test("the priority stays when the kind changes")
  func thePriorityStaysWhenTheKindChanges() {
    let (library, _) = makeInbox(priorityLog)
    library.show(.priorities)
    library.selectPriorities([.critical])
    library.addTask(withPriority: .critical)

    library.setNewItemKind(.project(.parallel))
    library.setNewItemKind(.task)

    #expect(library.newItem?.card.priority == .critical)
  }

  @Test("OK files the task at the bottom of that priority's list, and selects it")
  func okFilesTheTaskInTheList() throws {
    let (library, _) = makeInbox(priorityLog)
    library.show(.priorities)
    library.selectPriorities([.critical, .optional])
    library.addTask(withPriority: .optional)
    library.setNewItemTitle("water plants")

    library.saveNewItem(try #require(library.newItem?.card))

    let plants = try #require(library.tasks.first { $0.title == "water plants" })
    #expect(plants.priority == .optional)
    #expect(plants.parentID == nil)
    #expect(library.priorityGroups.map { $0.tasks.map(\.title) } == [["call bank"], ["tidy desk", "water plants"]])
    #expect(library.selection == plants.id)
    #expect(library.newItem == nil)
  }

  @Test("going to another place drops the task begun")
  func leavingDropsIt() {
    let (library, _) = makeInbox(priorityLog)
    library.show(.priorities)
    library.selectPriorities([.critical])
    library.addTask(withPriority: .critical)

    library.show(.inbox)

    #expect(library.newItem == nil)
  }
}
