import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given a default priority and estimate for projects in the settings")
struct ProjectDefaultsFlowTests {
  @Test("a new top-level project starts with them and a task deep inside takes them from the root project")
  func aTaskTakesThemFromTheRootProject() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.show(.settings)
    library.changeGlobalSetting(.defaultProjectPriority, to: "B")
    library.changeGlobalSetting(.defaultProjectEstimateMinutes, to: "30")
    library.show(.projects)

    library.beginNewItem(under: nil, kind: .project(.parallel))
    #expect(library.newItem?.card.priority == .important)
    #expect(library.newItem?.card.estimate == 30)
    library.setNewItemTitle("Home")
    library.saveNewItem(try #require(library.newItem?.card))
    let home = try #require(library.projects.first { $0.title == "Home" })
    let kitchen = try library.createProject("Kitchen", kind: .parallel)
    library.beginNewItem(under: kitchen, kind: .task)
    library.setNewItemTitle("replace tap")
    library.saveNewItem(try #require(library.newItem?.card))

    let relaunched = launchApp(on: dir.file("events.jsonl"))
    let homeAfter = try #require(relaunched.projects.first { $0.id == home.id })
    #expect(homeAfter.priority == .important)
    #expect(homeAfter.estimate == 30)
    let kitchenAfter = try #require(relaunched.projects.first { $0.id == kitchen })
    #expect(kitchenAfter.priority == nil)
    #expect(kitchenAfter.estimate == nil)
    relaunched.open(.project(kitchen))
    let tap = try relaunched.task("replace tap")
    #expect(relaunched.tasks.first { $0.id == tap }?.priority == .important)
    #expect(relaunched.tasks.first { $0.id == tap }?.estimate == 30)
  }

  @Test("with none set a new project and a task in the inbox start with neither")
  func withNoneSetNothingIsGiven() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))

    let europe = try library.createProject("Europe", kind: .parallel)
    library.capture("buy milk")

    let europeAfter = try #require(library.projects.first { $0.id == europe })
    #expect(europeAfter.priority == nil)
    #expect(europeAfter.estimate == nil)
    let milk = try #require(library.tasks.first { $0.title == "buy milk" })
    #expect(milk.priority == nil)
    #expect(milk.estimate == nil)
  }
}

@MainActor
@Suite("Given the Prios place, when Add Tasks is pressed at the bottom of a priority's list")
struct PriorityListAddTasksFlowTests {
  @Test("the task is made with that priority and shows at the bottom of that list")
  func theTaskLandsInThatList() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("call bank !a")
    library.show(.priorities)
    library.selectPriorities([.critical, .important])

    library.addTask(withPriority: .important)
    library.setNewItemTitle("pay rent")
    library.saveNewItem(try #require(library.newItem?.card))

    #expect(library.priorityGroups.map { $0.tasks.map(\.title) } == [["call bank"], ["pay rent"]])
    let relaunched = launchApp(on: dir.file("events.jsonl"))
    relaunched.show(.priorities)
    relaunched.selectPriorities([.important])
    #expect(relaunched.priorityGroups.map { $0.tasks.map(\.title) } == [["pay rent"]])
  }

  @Test("the list shows the due date of its tasks")
  func theListShowsDueDates() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    library.capture("call bank !a")
    library.show(.priorities)
    library.selectPriorities([.critical])
    let bank = try library.task("call bank")
    library.setDue(bank, to: date("2026-10-30"), isHard: false)

    let listed = try #require(library.priorityGroups.first?.tasks.first)
    #expect(library.dueDate(of: listed.id)?.date == date("2026-10-30"))
  }
}
