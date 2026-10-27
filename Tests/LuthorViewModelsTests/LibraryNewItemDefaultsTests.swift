import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// Garden (priority optional, 5 minutes) holds "mow the lawn" and the sub-project Roses.
private let gardenLog = [
  projectCreated("p1", "Garden", lamport: 1),
  captured("t1", "mow the lawn", under: "p1", lamport: 2),
  projectCreated("p2", "Roses", under: "p1", lamport: 3),
  prioritized("p1", as: .optional, lamport: 4),
  estimated("p1", as: 5, lamport: 5),
]

@MainActor
@Suite("When the plus button of a column is pressed, the defaults of the new item")
struct NewItemDefaultsViewModelTests {
  @Test("a new top-level project starts with the priority and estimate set in settings")
  func aNewTopLevelProjectStartsWithTheSettings() {
    let (library, _) = makeInbox(
      gardenLog + [
        settingChanged(.defaultProjectPriority, to: "B", lamport: 7),
        settingChanged(.defaultProjectEstimateMinutes, to: "60", lamport: 8),
      ])

    library.beginNewItem(under: nil, kind: .project(.parallel))

    #expect(library.newItem?.card.priority == .important)
    #expect(library.newItem?.card.estimate == 60)
  }

  @Test("a new sub-project starts with neither, whatever the settings and its project hold")
  func aNewSubProjectStartsWithNeither() {
    let (library, _) = makeInbox(gardenLog + [settingChanged(.defaultProjectPriority, to: "B", lamport: 7)])

    library.beginNewItem(under: TaskID("p1"), kind: .project(.parallel))

    #expect(library.newItem?.card.priority == nil)
    #expect(library.newItem?.card.estimate == nil)
  }

  @Test("a new task in a project with nothing set takes what the project above it holds")
  func aNewTaskTakesTheNearestAbove() {
    let (library, _) = makeInbox(gardenLog)

    library.beginNewItem(under: TaskID("p2"), kind: .task)

    #expect(library.newItem?.card.priority == .optional)
    #expect(library.newItem?.card.estimate == 5)
  }

  @Test("a new task in no project starts with neither, whatever the settings hold")
  func aNewTaskInNoProjectStartsWithNeither() {
    let (library, _) = makeInbox(gardenLog + [settingChanged(.defaultProjectPriority, to: "B", lamport: 7)])

    library.beginNewItem(under: nil, kind: .task)

    #expect(library.newItem?.card.priority == nil)
    #expect(library.newItem?.card.estimate == nil)
  }
}
