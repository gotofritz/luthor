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
@Suite("When a task begun outside a project is given one on its card")
struct NewItemProjectViewModelTests {
  @Test("it is filed in that project when kept")
  func itIsFiledInTheProject() throws {
    let (library, _) = makeInbox(gardenLog)
    library.addTask(withPriority: .important)
    library.setNewItemProject(TaskID("p1"))
    library.setNewItemTitle("prune")
    let card = try #require(library.newItem?.card)

    library.saveNewItem(card)

    let prune = try #require(library.tasks.first { $0.title == "prune" })
    #expect(prune.parentID == TaskID("p1"))
    #expect(prune.priority == .important)
  }

  @Test("the estimate follows the project, the priority picked stays")
  func theEstimateFollowsTheProject() {
    let (library, _) = makeInbox(gardenLog)
    library.addTask(withPriority: .important)

    library.setNewItemProject(TaskID("p1"))

    #expect(library.newItem?.parentID == TaskID("p1"))
    #expect(library.newItem?.card.priority == .important)
    #expect(library.newItem?.card.estimate == 5)
  }

  @Test("choosing no project again files it nowhere")
  func noProjectAgain() {
    let (library, _) = makeInbox(gardenLog)
    library.addTask(withPriority: nil)
    library.setNewItemProject(TaskID("p1"))

    library.setNewItemProject(nil)

    #expect(library.newItem?.parentID == nil)
    #expect(library.newItem?.card.estimate == nil)
  }
}
