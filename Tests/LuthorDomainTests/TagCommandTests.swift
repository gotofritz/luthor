import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

private let base = [
  viewCreated("work", "Work", lamport: 0),
  captured("t1", "call bank", lamport: 1),
  tagCreated("calls", "calls", lamport: 1),
  tagCreated("deep", "deep-work", view: "work", lamport: 1),
]

@Suite("When a tag is created by command")
struct TagCreateCommandTests {
  @Test("it writes one TagCreated in the view")
  func itWritesOneTagCreated() throws {
    let events = try makeCommands().createTag(named: "home", in: .default, log: base)

    #expect(events == [tagCreated("id-2", "home", id: "id-1", lamport: 2)])
  }

  @Test("an at sign and surrounding space are not part of the name")
  func anAtSignIsNotPartOfTheName() throws {
    let events = try makeCommands().createTag(named: "  @home ", in: .default, log: base)

    #expect(events == [tagCreated("id-2", "home", id: "id-1", lamport: 2)])
  }

  @Test("a blank name, or an at sign alone, is refused", arguments: ["", "   ", "@", " @ "])
  func aBlankNameIsRefused(name: String) {
    #expect(throws: CommandError.blankTitle) {
      try makeCommands().createTag(named: name, in: .default, log: base)
    }
  }

  @Test("a name the view has is refused, in any case")
  func aNameTheViewHasIsRefused() {
    #expect(throws: CommandError.duplicateTagName("Calls")) {
      try makeCommands().createTag(named: "@Calls", in: .default, log: base)
    }
  }

  @Test("a name only another view has is fine")
  func aNameOnlyAnotherViewHasIsFine() throws {
    let events = try makeCommands().createTag(named: "calls", in: ViewID("work"), log: base)

    #expect(events == [tagCreated("id-2", "calls", view: "work", id: "id-1", lamport: 2)])
  }

  @Test("a view that does not exist is refused")
  func aViewThatDoesNotExistIsRefused() {
    #expect(throws: CommandError.noView(ViewID("nowhere"))) {
      try makeCommands().createTag(named: "home", in: ViewID("nowhere"), log: base)
    }
  }
}

@Suite("When a task is tagged by command")
struct TagTaskCommandTests {
  @Test("it writes one TaskTagged")
  func itWritesOneTaskTagged() throws {
    let events = try makeCommands().tag(taskID: TaskID("t1"), with: TagID("calls"), log: base)

    #expect(events == [tagged("t1", with: "calls", id: "id-1", lamport: 2)])
  }

  @Test("tagging a task with a tag it has writes nothing")
  func taggingWithATagItHasWritesNothing() throws {
    let log = base + [tagged("t1", with: "calls")]

    #expect(try makeCommands().tag(taskID: TaskID("t1"), with: TagID("calls"), log: log) == [])
  }

  @Test("a task that is not open is refused")
  func aTaskThatIsNotOpenIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().tag(taskID: TaskID("t9"), with: TagID("calls"), log: base)
    }
  }

  @Test("a tag that does not exist is refused")
  func aTagThatDoesNotExistIsRefused() {
    #expect(throws: CommandError.noTag(TagID("ghost"))) {
      try makeCommands().tag(taskID: TaskID("t1"), with: TagID("ghost"), log: base)
    }
  }

  @Test("a tag of another view is refused")
  func aTagOfAnotherViewIsRefused() {
    #expect(throws: CommandError.tagInOtherView(TaskID("t1"), TagID("deep"))) {
      try makeCommands().tag(taskID: TaskID("t1"), with: TagID("deep"), log: base)
    }
  }

  @Test("untagging writes one TaskUntagged, and nothing for a tag the task does not have")
  func untaggingWritesOneTaskUntagged() throws {
    let log = base + [tagged("t1", with: "calls")]

    #expect(
      try makeCommands().untag(taskID: TaskID("t1"), from: TagID("calls"), log: log)
        == [untagged("t1", from: "calls", id: "id-1", lamport: 3)])
    #expect(try makeCommands().untag(taskID: TaskID("t1"), from: TagID("calls"), log: base) == [])
  }

  @Test("untagging a task that is not open is refused")
  func untaggingATaskThatIsNotOpenIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().untag(taskID: TaskID("t9"), from: TagID("calls"), log: base)
    }
  }
}

@Suite("When a task is tagged by name")
struct TagByNameCommandTests {
  @Test("a name the view has tags the task with that tag, ignoring case and the at sign")
  func aNameTheViewHasTagsTheTask() throws {
    let events = try makeCommands().tag(taskID: TaskID("t1"), named: "@Calls", log: base)

    #expect(events == [tagged("t1", with: "calls", id: "id-1", lamport: 2)])
  }

  @Test("a new name creates the tag in the task's view and tags the task")
  func aNewNameCreatesTheTag() throws {
    let events = try makeCommands().tag(taskID: TaskID("t1"), named: "home", log: base)

    #expect(
      events == [
        tagCreated("id-2", "home", id: "id-1", lamport: 2),
        tagged("t1", with: "id-2", id: "id-3", lamport: 3),
      ])
  }

  @Test("a task that has the tag already, and a blank name, write nothing and are refused")
  func aTaskThatHasTheTagAndABlankName() throws {
    let log = base + [tagged("t1", with: "calls")]

    #expect(try makeCommands().tag(taskID: TaskID("t1"), named: "calls", log: log) == [])
    #expect(throws: CommandError.blankTitle) {
      try makeCommands().tag(taskID: TaskID("t1"), named: " @ ", log: log)
    }
  }

  @Test("a task that is not open is refused")
  func aTaskThatIsNotOpenIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().tag(taskID: TaskID("t9"), named: "home", log: base)
    }
  }
}

@Suite("When the tags of a task are set by command")
struct SetTagsCommandTests {
  private static let log =
    base + [
      tagCreated("home", "home", lamport: 2), tagged("t1", with: "calls", lamport: 3),
      tagged("t1", with: "home", lamport: 4),
    ]

  @Test("tags the task has not got are added, creating those the view lacks")
  func tagsTheTaskHasNotGotAreAdded() throws {
    let log = base + [tagged("t1", with: "calls", lamport: 2)]

    let events = try makeCommands().setTags(taskID: TaskID("t1"), to: ["calls", "errands"], log: log)

    #expect(
      events == [
        tagCreated("id-2", "errands", id: "id-1", lamport: 3),
        tagged("t1", with: "id-2", id: "id-3", lamport: 4),
      ])
  }

  @Test("tags the task has and the list lacks are taken off")
  func tagsTheListLacksAreTakenOff() throws {
    let events = try makeCommands().setTags(taskID: TaskID("t1"), to: ["home"], log: Self.log)

    #expect(events == [untagged("t1", from: "calls", id: "id-1", lamport: 5)])
  }

  @Test("the same tags, in any case and order and with at signs, write nothing")
  func theSameTagsWriteNothing() throws {
    let events = try makeCommands().setTags(taskID: TaskID("t1"), to: ["@Home", " calls ", "HOME", ""], log: Self.log)

    #expect(events == [])
  }

  @Test("an empty list takes every tag off")
  func anEmptyListTakesEveryTagOff() throws {
    let events = try makeCommands().setTags(taskID: TaskID("t1"), to: [], log: Self.log)

    #expect(
      events == [
        untagged("t1", from: "calls", id: "id-1", lamport: 5),
        untagged("t1", from: "home", id: "id-2", lamport: 6),
      ])
  }

  @Test("a task that is not open is refused")
  func aTaskThatIsNotOpenIsRefused() {
    #expect(throws: CommandError.noOpenTask("t9")) {
      try makeCommands().setTags(taskID: TaskID("t9"), to: ["home"], log: Self.log)
    }
  }
}
