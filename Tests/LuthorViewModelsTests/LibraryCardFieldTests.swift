import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Observation
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
@Suite("When a field of a card is changed on the card itself")
struct CardFieldInPlaceTests {
  @Test("a task's priority, estimate and due date each take effect at once")
  func taskFieldsApplyAtOnce() {
    let (library, _) = makeLibrary()
    library.open(.project(TaskID("p1")))
    library.selection = TaskID("t1")

    library.prioritize(TaskID("t1"), as: .important)
    library.estimate(TaskID("t1"), as: 30)
    library.setDue(TaskID("t1"), to: date("2026-10-30"), isHard: false)

    #expect(library.selectedTask?.priority == .important)
    #expect(library.selectedTask?.estimate == 30)
    #expect(library.dueDate(of: TaskID("t1")) == DueDate(date: date("2026-10-30"), isHard: false))
  }

  @Test("setting the tags replaces the ones the task has")
  func tagsAreReplaced() {
    let (library, _) = makeLibrary()
    library.tagTask(TaskID("t2"), named: "home")

    library.setTags(TaskID("t2"), to: ["calls", "errands"])

    #expect(library.tagItems(of: TaskID("t2")).map(\.name).sorted() == ["calls", "errands"])
  }
}

private final class Told: @unchecked Sendable {
  var value = false
}

@MainActor
@Suite("When a card field read from the log changes")
struct CardFieldObservationTests {
  @Test("a view that read the due date is told", arguments: ["due", "repeat", "tags", "review"])
  func readersAreNotified(field: String) {
    let (library, _) = makeLibrary()
    let told = Told()

    withObservationTracking {
      switch field {
      case "due": _ = library.dueDate(of: TaskID("t1"))
      case "repeat": _ = library.repeatRule(of: TaskID("t1"))
      case "tags": _ = library.tagItems(of: TaskID("t1"))
      default: _ = library.nextReviewDate(of: TaskID("p1"))
      }
    } onChange: {
      told.value = true
    }
    library.setDue(TaskID("t1"), to: date("2026-10-30"), isHard: true)

    #expect(told.value)
  }
}

private let treeLog = [
  projectCreated("p1", "Holiday", lamport: 1),
  projectCreated("p2", "Flights", under: "p1", lamport: 2),
  projectCreated("p3", "Garden", lamport: 3),
  captured("t1", "book flights", lamport: 4), moved("t1", to: "p2", lamport: 5),
]

@MainActor
@Suite("When a card offers the project tree")
struct ProjectOutlineTests {
  @Test("it lists every project under its parent, with its depth")
  func listsTheTree() {
    let (library, _) = makeLibrary(treeLog)

    let outline = library.projectOutline()

    #expect(outline.map(\.id) == [TaskID("p1"), TaskID("p2"), TaskID("p3")])
    #expect(outline.map(\.depth) == [0, 1, 0])
  }

  @Test("it leaves out a project and everything inside it, so a project cannot be put under itself")
  func leavesOutTheSubtree() {
    let (library, _) = makeLibrary(treeLog)

    let outline = library.projectOutline(excludingSubtreeOf: TaskID("p1"))

    #expect(outline.map(\.id) == [TaskID("p3")])
  }

  @Test("filing a task into another project moves it")
  func filingMovesTheTask() {
    let (library, _) = makeLibrary(treeLog)

    library.file(TaskID("t1"), into: TaskID("p3"))

    #expect(library.knownProjects.first { $0.id == TaskID("p3") }?.children.count == 1)
  }

  @Test("filing a task into no project takes it out of its project")
  func filingIntoNothingTakesItOut() {
    let (library, _) = makeLibrary(treeLog)

    library.file(TaskID("t1"), into: nil)

    #expect(library.knownProjects.first { $0.id == TaskID("p2") }?.children.isEmpty == true)
  }
}
