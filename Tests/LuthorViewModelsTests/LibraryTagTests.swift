import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

private let monday = date("2026-10-19")

@MainActor
private func makeLibrary(_ events: [EventEnvelope] = []) -> (LibraryViewModel, InMemoryEventLog) {
  let log = InMemoryEventLog(events)
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()), today: { monday })
  library.reload()
  return (library, log)
}

private let tagged3 = [
  viewCreated("work", "Work", lamport: 0),
  captured("t1", "call bank", lamport: 1), captured("t2", "pay tax", lamport: 1),
  captured("t3", "write report", lamport: 1), captured("t4", "review plan", view: "work", lamport: 1),
  tagCreated("calls", "calls", lamport: 1), tagCreated("home", "home", lamport: 1),
  tagCreated("deep", "deep-work", view: "work", lamport: 1),
  tagged("t1", with: "calls", lamport: 2), tagged("t2", with: "calls", lamport: 2),
  tagged("t2", with: "home", lamport: 3), tagged("t4", with: "deep", lamport: 2),
]

@MainActor
@Suite("When the Tags place is shown")
struct LibraryTagsPlaceTests {
  @Test("the rail has it after Prios and before Settings")
  func theRailHasItAfterPrios() {
    let sections = NavigationSection.allCases

    #expect(sections.firstIndex(of: .tags) == sections.firstIndex(of: .priorities).map { $0 + 1 })
    #expect(sections.firstIndex(of: .settings) == sections.firstIndex(of: .tags).map { $0 + 1 })
  }

  @Test("the first column lists the tags of the view, with how many open tasks each has")
  func theFirstColumnListsTheTagsOfTheView() {
    let (library, _) = makeLibrary(tagged3)

    library.show(.tags)

    #expect(library.tags.map(\.name) == ["calls", "home"])
    #expect(library.tagTaskCounts == [TagID("calls"): 2, TagID("home"): 1])
  }

  @Test("no task is listed until a tag is picked, and then the tasks that carry it")
  func tasksAreListedOnceATagIsPicked() {
    let (library, _) = makeLibrary(tagged3)
    library.show(.tags)
    #expect(library.tasks.isEmpty)
    #expect(library.selectedTagID == nil)

    library.showTag(TagID("calls"))

    #expect(library.selectedTagID == TagID("calls"))
    #expect(library.tasks.map(\.title) == ["call bank", "pay tax"])
  }

  @Test("completing a task takes it off its tag's list and the count")
  func completingATaskTakesItOffTheList() {
    let (library, _) = makeLibrary(tagged3)
    library.show(.tags)
    library.showTag(TagID("calls"))

    library.complete(TaskID("t1"))

    #expect(library.tasks.map(\.title) == ["pay tax"])
    #expect(library.tagTaskCounts[TagID("calls")] == 1)
  }

  @Test("another view has its own tags, and the tag picked in the first is dropped")
  func anotherViewHasItsOwnTags() {
    let (library, _) = makeLibrary(tagged3)
    library.show(.tags)
    library.showTag(TagID("calls"))

    library.showView(ViewID("work"))
    library.show(.tags)

    #expect(library.tags.map(\.name) == ["deep-work"])
    #expect(library.selectedTagID == nil)
    #expect(library.tasks.isEmpty)
  }

  @Test("the tag stays picked when the rail comes back to Tags")
  func theTagStaysPicked() {
    let (library, _) = makeLibrary(tagged3)
    library.show(.tags)
    library.showTag(TagID("home"))

    library.show(.inbox)
    library.show(.tags)

    #expect(library.selectedTagID == TagID("home"))
    #expect(library.tasks.map(\.title) == ["pay tax"])
  }

  @Test("picking a tag selects no task")
  func pickingATagSelectsNoTask() {
    let (library, _) = makeLibrary(tagged3)
    library.show(.tags)
    library.showTag(TagID("calls"))
    library.selection = TaskID("t1")

    library.showTag(TagID("home"))

    #expect(library.selection == nil)
  }
}

@MainActor
@Suite("When a task is tagged in the window")
struct LibraryTaggingTests {
  @Test("a new name creates the tag and tags the task")
  func aNewNameCreatesTheTag() {
    let (library, log) = makeLibrary([captured("t1", "call bank", lamport: 1)])

    library.tagTask(TaskID("t1"), named: "@calls")

    #expect(
      Array(log.events.suffix(2)) == [
        tagCreated("id-2", "calls", id: "id-1", lamport: 2),
        tagged("t1", with: "id-2", id: "id-3", lamport: 3),
      ])
    #expect(library.tagItems(of: TaskID("t1")).map(\.name) == ["calls"])
  }

  @Test("a name the view has reuses its tag")
  func aNameTheViewHasReusesItsTag() {
    let (library, log) = makeLibrary(tagged3)

    library.tagTask(TaskID("t3"), named: "Calls")

    #expect(log.events.last == tagged("t3", with: "calls", id: "id-1", lamport: 4))
  }

  @Test("toggling a tag puts it on a task and takes it off again")
  func togglingATagPutsItOnAndTakesItOff() {
    let (library, log) = makeLibrary(tagged3)

    library.toggleTag(TagID("home"), on: TaskID("t1"))
    #expect(library.tagItems(of: TaskID("t1")).map(\.name) == ["calls", "home"])

    library.toggleTag(TagID("home"), on: TaskID("t1"))
    #expect(library.tagItems(of: TaskID("t1")).map(\.name) == ["calls"])
    #expect(log.events.suffix(2).map(\.id.rawValue) == ["id-1", "id-2"])
  }

  @Test("a tag that does not exist, or a task that is not open, changes nothing")
  func anUnknownTagOrTaskChangesNothing() {
    let (library, log) = makeLibrary(tagged3)

    library.toggleTag(TagID("ghost"), on: TaskID("t1"))
    library.toggleTag(TagID("home"), on: TaskID("t9"))

    #expect(log.events == tagged3)
  }

  @Test("OK on a card keeps the tags typed, and a draft with none takes them off")
  func okOnACardKeepsTheTags() {
    let (library, _) = makeLibrary(tagged3)
    let draft = TaskCardDraft(
      title: "write report", priority: nil, estimate: nil, due: nil, notes: "", tags: ["calls", "errands"])

    library.editCard(.task(TaskID("t3")))
    library.saveCard(ofTask: TaskID("t3"), draft)
    #expect(library.tagItems(of: TaskID("t3")).map(\.name) == ["calls", "errands"])

    library.editCard(.task(TaskID("t3")))
    library.saveCard(
      ofTask: TaskID("t3"), TaskCardDraft(title: "write report", priority: nil, estimate: nil, due: nil, notes: ""))
    #expect(library.tagItems(of: TaskID("t3")).isEmpty)
  }

  @Test("tag names are read from comma-separated text, without blanks, at signs or repeats")
  func tagNamesAreReadFromText() {
    #expect(TaskCardDraft.tagNames(in: "calls, @home ,, Calls,deep-work") == ["calls", "home", "deep-work"])
    #expect(TaskCardDraft.tagNames(in: "  ") == [])
  }
}

@MainActor
@Suite("When Today's candidates are filtered in the window")
struct LibraryCandidateFilterTests {
  private static let events = tagged3 + [prioritized("t1", as: .critical), prioritized("t3", as: .important)]

  @Test("a tag keeps the candidates that carry it, and clearing the filter brings the rest back")
  func aTagKeepsTheCandidatesThatCarryIt() {
    let (library, _) = makeLibrary(Self.events)
    library.show(.today)
    #expect(library.plan.candidates.map(\.task.title) == ["call bank", "write report"])

    library.candidateFilter = TaskFilter(tags: [TagID("calls")])
    #expect(library.plan.candidates.map(\.task.title) == ["call bank"])
    #expect(library.tasks.map(\.title) == ["call bank"])

    library.candidateFilter = TaskFilter()
    #expect(library.plan.candidates.map(\.task.title) == ["call bank", "write report"])
  }

  @Test("toggling a tag narrows the candidates to it, and toggling it again drops it")
  func togglingATagNarrowsTheCandidates() {
    let (library, _) = makeLibrary(Self.events)
    library.show(.today)

    library.toggleCandidateTag(TagID("calls"))
    #expect(library.candidateFilter == TaskFilter(tags: [TagID("calls")]))
    #expect(library.plan.candidates.map(\.task.title) == ["call bank"])

    library.toggleCandidateTag(TagID("calls"))
    #expect(library.candidateFilter.isEmpty)
  }

  @Test("the tasks planned for the day are listed whatever the filter")
  func thePlannedTasksAreListed() {
    let (library, _) = makeLibrary(Self.events + [scheduled("t3", on: "2026-10-19", lamport: 4)])
    library.show(.today)

    library.candidateFilter = TaskFilter(tags: [TagID("calls")])

    #expect(library.plan.entries.map(\.task.title) == ["write report"])
    #expect(library.plan.candidates.map(\.task.title) == ["call bank"])
  }

  @Test("switching to another view drops the filter")
  func switchingViewsDropsTheFilter() {
    let (library, _) = makeLibrary(Self.events)
    library.candidateFilter = TaskFilter(tags: [TagID("calls")])

    library.showView(ViewID("work"))

    #expect(library.candidateFilter.isEmpty)
  }
}
