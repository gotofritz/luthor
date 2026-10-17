import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
func makeInbox(_ events: [EventEnvelope] = []) -> (InboxViewModel, InMemoryEventLog) {
  let log = InMemoryEventLog(events)
  let inbox = InboxViewModel(log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()))
  inbox.reload()
  return (inbox, log)
}

@MainActor
@Suite struct InboxLoadingTests {
  @Test func reloadShowsTheOpenTasksInCaptureOrder() {
    let (inbox, _) = makeInbox([
      captured("t1", "buy milk", lamport: 1),
      captured("t2", "call mum", lamport: 2),
      completed("t1", lamport: 3),
      captured("t3", "pay rent", lamport: 4),
    ])

    #expect(inbox.tasks == [item("t2", "call mum"), item("t3", "pay rent")])
  }

  @Test func reloadPicksUpEventsWrittenElsewhere() {
    let (inbox, log) = makeInbox([captured("t1", "buy milk", lamport: 1)])

    log.events.append(captured("t2", "call mum", device: "cli", lamport: 2))
    inbox.reload()

    #expect(inbox.tasks == [item("t1", "buy milk"), item("t2", "call mum")])
  }

  @Test func unreadableLogShowsTheLine() {
    let (inbox, log) = makeInbox()

    log.readFailure = .unreadableLine(3)
    inbox.reload()

    #expect(inbox.errorMessage == "Line 3 of the event log is not a readable event.")
  }
}

@MainActor
@Suite struct InboxCaptureTests {
  @Test func submitCapturesTheDraftAndClearsIt() {
    let (inbox, log) = makeInbox()
    inbox.draft = "buy milk"

    inbox.submit()

    #expect(log.events == [captured("id-2", "buy milk", id: "id-1", lamport: 1)])
    #expect(inbox.tasks == [item("id-2", "buy milk")])
    #expect(inbox.draft == "")
  }

  @Test(arguments: ["", "  ", "\n"])
  func submitIgnoresABlankDraft(draft: String) {
    let (inbox, log) = makeInbox()
    inbox.draft = draft

    inbox.submit()

    #expect(log.events == [])
    #expect(inbox.errorMessage == nil)
  }

  @Test func submitFollowsEventsWrittenSinceTheLastReload() {
    let (inbox, log) = makeInbox([captured("t1", "buy milk", lamport: 1)])
    log.events.append(captured("t2", "call mum", device: "cli", lamport: 2))
    inbox.draft = "pay rent"

    inbox.submit()

    #expect(log.events.last?.lamport == 3)
    #expect(inbox.tasks.map(\.title) == ["buy milk", "call mum", "pay rent"])
  }

  @Test func failedAppendKeepsTheDraftAndShowsTheError() {
    let (inbox, log) = makeInbox()
    log.appendFailure = .ioFailure("disk full")
    inbox.draft = "buy milk"

    inbox.submit()

    #expect(inbox.draft == "buy milk")
    #expect(inbox.errorMessage == "disk full")
    #expect(inbox.tasks == [])
  }

  @Test func unreadableLogBlocksCapture() {
    let (inbox, log) = makeInbox([captured("t1", "buy milk")])
    log.readFailure = .unreadableLine(2)
    inbox.draft = "call mum"

    inbox.submit()

    #expect(log.events == [captured("t1", "buy milk")])
    #expect(inbox.draft == "call mum")
    #expect(inbox.errorMessage == "Line 2 of the event log is not a readable event.")
  }

  @Test func successfulCaptureClearsAnEarlierError() {
    let (inbox, log) = makeInbox()
    log.appendFailure = .ioFailure("disk full")
    inbox.draft = "buy milk"
    inbox.submit()

    log.appendFailure = nil
    inbox.submit()

    #expect(inbox.errorMessage == nil)
  }
}

@MainActor
@Suite struct InboxCompletionTests {
  @Test func completeRemovesTheTaskAndAppendsTaskCompleted() {
    let (inbox, log) = makeInbox([captured("t1", "buy milk", lamport: 1), captured("t2", "call mum", lamport: 2)])

    inbox.complete(TaskID("t1"))

    #expect(log.events.last == completed("t1", id: "id-1", lamport: 3))
    #expect(inbox.tasks == [item("t2", "call mum")])
  }

  @Test func completingATaskAlreadyCompletedElsewhereJustReloads() {
    let (inbox, log) = makeInbox([captured("t1", "buy milk", lamport: 1)])
    log.events.append(completed("t1", device: "cli", lamport: 2))

    inbox.complete(TaskID("t1"))

    #expect(log.events.count == 2)
    #expect(inbox.tasks == [])
    #expect(inbox.errorMessage == nil)
  }

  @Test func failedCompletionKeepsTheTaskAndShowsTheError() {
    let (inbox, log) = makeInbox([captured("t1", "buy milk")])
    log.appendFailure = .ioFailure("disk full")

    inbox.complete(TaskID("t1"))

    #expect(inbox.tasks == [item("t1", "buy milk")])
    #expect(inbox.errorMessage == "disk full")
  }
}

@MainActor
@Suite struct InboxSelectionTests {
  static let log = [
    captured("t1", "buy milk", lamport: 1),
    captured("t2", "call mum", lamport: 2),
    captured("t3", "pay rent", lamport: 3),
  ]

  @Test(
    arguments: [
      (nil, 1, "t1"),
      (nil, -1, "t3"),
      ("t1", 1, "t2"),
      ("t2", -1, "t1"),
      ("t3", 1, "t3"),
      ("t1", -1, "t1"),
    ] as [(String?, Int, String)])
  func moveSelectionStepsThroughTheListAndStopsAtTheEnds(start: String?, offset: Int, expected: String) {
    let (inbox, _) = makeInbox(Self.log)
    inbox.selection = start.map(TaskID.init)

    inbox.moveSelection(by: offset)

    #expect(inbox.selection == TaskID(expected))
  }

  @Test func moveSelectionInAnEmptyInboxSelectsNothing() {
    let (inbox, _) = makeInbox()

    inbox.moveSelection(by: 1)

    #expect(inbox.selection == nil)
  }

  @Test func completeSelectedCompletesItAndSelectsTheNextTask() {
    let (inbox, log) = makeInbox(Self.log)
    inbox.selection = TaskID("t2")

    inbox.completeSelected()

    #expect(log.events.last?.payload == .taskCompleted(TaskCompleted(taskID: TaskID("t2"))))
    #expect(inbox.selection == TaskID("t3"))
  }

  @Test func completingTheLastTaskSelectsTheOneBefore() {
    let (inbox, _) = makeInbox(Self.log)
    inbox.selection = TaskID("t3")

    inbox.completeSelected()

    #expect(inbox.selection == TaskID("t2"))
  }

  @Test func completingTheOnlyTaskLeavesNothingSelected() {
    let (inbox, _) = makeInbox([captured("t1", "buy milk")])
    inbox.selection = TaskID("t1")

    inbox.completeSelected()

    #expect(inbox.selection == nil)
  }

  @Test func completeSelectedWithoutASelectionDoesNothing() {
    let (inbox, log) = makeInbox(Self.log)

    inbox.completeSelected()

    #expect(log.events == Self.log)
  }

  @Test func reloadDropsTheSelectionOfATaskNoLongerOpen() {
    let (inbox, log) = makeInbox(Self.log)
    inbox.selection = TaskID("t1")

    log.events.append(completed("t1", device: "cli", lamport: 4))
    inbox.reload()

    #expect(inbox.selection == nil)
  }
}
