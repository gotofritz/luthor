import LuthorDomain
import LuthorTestSupport
import Testing

private let work = [
  viewCreated("work", "Work", lamport: 0),
  captured("t1", "call bank", lamport: 1),
  captured("t2", "write report", view: "work", lamport: 1),
  tagCreated("calls", "calls", lamport: 1),
  tagCreated("deep", "deep-work", view: "work", lamport: 1),
]

@Suite("When tags are replayed")
struct TagReplayTests {
  @Test("a tag belongs to the view it was created in, in creation order")
  func aTagBelongsToItsView() {
    let state = LibraryState.replay(work + [tagCreated("home", "home", lamport: 2)])

    #expect(
      state.tags(in: .default) == [
        TagItem(id: TagID("calls"), name: "calls", viewID: .default),
        TagItem(id: TagID("home"), name: "home", viewID: .default),
      ])
    #expect(state.tags(in: ViewID("work")) == [TagItem(id: TagID("deep"), name: "deep-work", viewID: ViewID("work"))])
  }

  @Test("the same name in two views is two different tags")
  func theSameNameInTwoViewsIsTwoTags() {
    let state = LibraryState.replay(work + [tagCreated("calls-work", "calls", view: "work", lamport: 2)])

    #expect(state.tags(in: .default).map(\.id) == [TagID("calls")])
    #expect(state.tags(in: ViewID("work")).map(\.id) == [TagID("deep"), TagID("calls-work")])
  }

  @Test("a tag created twice stays one tag")
  func aTagCreatedTwiceStaysOne() {
    let state = LibraryState.replay(work + [tagCreated("calls", "calls again", id: "again", lamport: 2)])

    #expect(state.tags(in: .default).map(\.name) == ["calls"])
  }

  @Test("a tag in a view that does not exist is ignored")
  func aTagInAnUnknownViewIsIgnored() {
    let state = LibraryState.replay(work + [tagCreated("ghost", "ghost", view: "nowhere", lamport: 2)])

    #expect(state.tags(in: ViewID("nowhere")).isEmpty)
  }

  @Test("a tagged task lists the tag, and the tag lists the task")
  func aTaggedTaskListsTheTag() {
    let state = LibraryState.replay(work + [tagged("t1", with: "calls")])

    #expect(state.tags(of: TaskID("t1")).map(\.name) == ["calls"])
    #expect(state.tasks(tagged: TagID("calls")) == [item("t1", "call bank")])
  }

  @Test("tagging twice is the same as tagging once")
  func taggingTwiceIsTheSameAsOnce() {
    let events = work + [tagged("t1", with: "calls"), tagged("t1", with: "calls", id: "again", lamport: 3)]
    let state = LibraryState.replay(events)

    #expect(state.tags(of: TaskID("t1")).count == 1)
  }

  @Test("a task has its tags in the order they were created")
  func aTaskHasItsTagsInCreationOrder() {
    let events = work + [
      tagCreated("home", "home", lamport: 2), tagged("t1", with: "home", lamport: 3),
      tagged("t1", with: "calls", lamport: 4),
    ]

    #expect(LibraryState.replay(events).tags(of: TaskID("t1")).map(\.name) == ["calls", "home"])
  }

  @Test("untagging takes the tag off and leaves the others")
  func untaggingTakesTheTagOff() {
    let events = work + [
      tagCreated("home", "home", lamport: 2), tagged("t1", with: "calls", lamport: 3),
      tagged("t1", with: "home", lamport: 4), untagged("t1", from: "calls", lamport: 5),
    ]
    let state = LibraryState.replay(events)

    #expect(state.tags(of: TaskID("t1")).map(\.name) == ["home"])
    #expect(state.tasks(tagged: TagID("calls")).isEmpty)
  }

  @Test("a tagged and untagged task is the same state as one never tagged")
  func aTaggedAndUntaggedTaskIsAsIfNeverTagged() {
    let state = LibraryState.replay(work + [tagged("t1", with: "calls"), untagged("t1", from: "calls")])

    #expect(state == LibraryState.replay(work))
  }

  @Test("a tag of another view cannot be put on a task")
  func aTagOfAnotherViewCannotBePutOnATask() {
    let state = LibraryState.replay(work + [tagged("t1", with: "deep")])

    #expect(state.tags(of: TaskID("t1")).isEmpty)
  }

  @Test("a tag that does not exist and a task that is not open are ignored")
  func anUnknownTagAndAClosedTaskAreIgnored() {
    let state = LibraryState.replay(
      work + [tagged("t1", with: "ghost"), completed("t1", lamport: 2), tagged("t1", with: "calls", lamport: 3)])

    #expect(state.tags(of: TaskID("t1")).isEmpty)
  }

  @Test("tags survive completing a task and reopening it")
  func tagsSurviveCompletionAndReopening() {
    let events = work + [tagged("t1", with: "calls"), completed("t1", lamport: 3), reopened("t1", lamport: 4)]

    #expect(LibraryState.replay(events).tasks(tagged: TagID("calls")) == [item("t1", "call bank")])
  }

  @Test("a completed task is not listed under its tag")
  func aCompletedTaskIsNotListed() {
    let state = LibraryState.replay(work + [tagged("t1", with: "calls"), completed("t1", lamport: 3)])

    #expect(state.tasks(tagged: TagID("calls")).isEmpty)
  }

  @Test("taking a task to another view takes its tags off")
  func takingATaskToAnotherViewTakesItsTagsOff() {
    let events = work + [tagged("t1", with: "calls"), movedToView("t1", toView: "work", lamport: 3)]
    let state = LibraryState.replay(events)

    #expect(state.tags(of: TaskID("t1")).isEmpty)
    #expect(state.tasks(tagged: TagID("calls")).isEmpty)
  }

  @Test("taking a project to another view takes the tags off its tasks")
  func takingAProjectToAnotherViewTakesTheTagsOffItsTasks() {
    let events = work + [
      projectCreated("p1", "taxes", lamport: 1), moved("t1", to: "p1", lamport: 2),
      tagged("t1", with: "calls", lamport: 3), projectMovedToView("p1", toView: "work", lamport: 4),
    ]

    #expect(LibraryState.replay(events).tags(of: TaskID("t1")).isEmpty)
  }

  @Test("tags are found by name in a view, ignoring case")
  func tagsAreFoundByNameIgnoringCase() {
    let state = LibraryState.replay(work)

    #expect(state.tag(named: "CALLS", in: .default)?.id == TagID("calls"))
    #expect(state.tag(named: "calls", in: ViewID("work")) == nil)
  }

  @Test("a view counts the open tasks of each of its tags, zero for a tag no open task carries")
  func aViewCountsTheOpenTasksOfEachTag() {
    let events = work + [
      captured("t3", "pay tax", lamport: 1), tagCreated("home", "home", lamport: 2),
      tagged("t1", with: "calls", lamport: 3), tagged("t3", with: "calls", lamport: 3), completed("t3", lamport: 4),
    ]

    let counts = LibraryState.replay(events).taskCounts(ofTagsIn: .default)

    #expect(counts == [TagID("calls"): 1, TagID("home"): 0])
  }

  @Test("the same events in any order give the same state")
  func theSameEventsInAnyOrderGiveTheSameState() {
    let events =
      work + [
        tagged("t1", with: "calls"), untagged("t1", from: "calls"),
        tagged("t1", with: "calls", id: "again", lamport: 4),
      ]

    #expect(LibraryState.replay(events) == LibraryState.replay(Array(events.reversed())))
    #expect(LibraryState.replay(events + events) == LibraryState.replay(events))
  }
}
