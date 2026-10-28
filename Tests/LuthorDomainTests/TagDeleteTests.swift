import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

private let base = [
  captured("t1", "call bank", lamport: 1),
  captured("t2", "write report", lamport: 2),
  tagCreated("calls", "calls", lamport: 3),
  tagCreated("deep", "deep-work", lamport: 4),
  tagged("t1", with: "calls", lamport: 5),
  tagged("t1", with: "deep", lamport: 6),
  tagged("t2", with: "calls", lamport: 7),
]

@Suite("When a tag is deleted")
struct TagDeleteReplayTests {
  @Test("it leaves the view's tags and every task that carried it")
  func itLeavesTheTagsAndTheTasks() {
    let state = LibraryState.replay(base + [tagDeleted("calls")])

    #expect(state.tags(in: .default).map(\.id) == [TagID("deep")])
    #expect(state.tags(of: TaskID("t1")).map(\.id) == [TagID("deep")])
    #expect(state.tags(of: TaskID("t2")).isEmpty)
    #expect(state.tasks(tagged: TagID("calls")).isEmpty)
  }

  @Test("a tag that does not exist is ignored")
  func anUnknownTagIsIgnored() {
    #expect(LibraryState.replay(base + [tagDeleted("nope")]) == LibraryState.replay(base))
  }

  @Test("the tags are still in the same order for those left, and the use of a tag is how many tasks carry it")
  func useCounts() {
    let state = LibraryState.replay(base + [completed("t2", lamport: 8)])

    #expect(state.tagUseCount(of: TagID("calls")) == 2)
    #expect(state.tagUseCount(of: TagID("deep")) == 1)
    #expect(state.tagUseCount(of: TagID("nope")) == 0)
  }
}

@Suite("When a tag is deleted by command")
struct TagDeleteCommandTests {
  @Test("it writes one TagDeleted")
  func writesOneTagDeleted() throws {
    let events = try makeCommands().deleteTag(TagID("calls"), log: base)

    #expect(events == [tagDeleted("calls", id: "id-1", lamport: 8)])
  }

  @Test("a tag that does not exist is refused")
  func unknownTagIsRefused() {
    #expect(throws: CommandError.noTag(TagID("nope"))) {
      try makeCommands().deleteTag(TagID("nope"), log: base)
    }
  }
}

@Suite("When deleting a tag is taken back")
struct TagDeleteUndoTests {
  @Test("the tag is made again and put back on the open tasks that carried it")
  func tagComesBack() {
    let undo = LibraryState.replay(base).undoStep(for: [tagDeleted("calls").payload])

    #expect(undo?.forward == [tagDeleted("calls").payload])
    #expect(
      undo?.backward == [
        tagCreated("calls", "calls").payload, tagged("t1", with: "calls").payload,
        tagged("t2", with: "calls").payload,
      ])
  }

  @Test("it cannot be taken back while a completed task carries the tag")
  func completedTaskMakesItFinal() {
    let log = base + [completed("t2", lamport: 8)]

    #expect(LibraryState.replay(log).undoStep(for: [tagDeleted("calls").payload]) == nil)
  }
}
