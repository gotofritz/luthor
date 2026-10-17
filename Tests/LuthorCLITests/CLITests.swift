import Foundation
import LuthorCLI
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import Testing

/// Runs the CLI against a log in a fresh temporary directory.
final class CLIHarness {
  let dir: TemporaryDirectory
  let logURL: URL
  let ids = SequentialIDs()
  var environment: [String: String]

  init() throws {
    dir = try TemporaryDirectory()
    logURL = dir.file("events.jsonl")
    environment = ["LUTHOR_LOG": logURL.path, "LUTHOR_DEVICE_ID": "mac"]
  }

  /// The home directory the CLI is told about; inside the temporary directory.
  var home: URL { dir.file("home") }

  deinit { dir.remove() }

  @discardableResult
  func run(_ arguments: String...) -> CLIResult {
    CLI(environment: environment, home: home, ids: ids).run(arguments)
  }

  func seed(_ events: [EventEnvelope]) throws {
    try JSONLinesEventLog(fileURL: logURL).append(events)
  }

  func log() throws -> [EventEnvelope] {
    try JSONLinesEventLog(fileURL: logURL).readAll()
  }
}

@Suite struct AddCommandTests {
  @Test func addAppendsATaskCapturedEventToTheLog() throws {
    let cli = try CLIHarness()

    let result = cli.run("add", "buy", "milk")

    #expect(result == CLIResult(exitCode: 0, output: "Captured id-2  buy milk\n"))
    #expect(
      try cli.log() == [
        EventEnvelope(
          id: EventID("id-1"),
          deviceID: DeviceID("mac"),
          lamport: 1,
          payload: .taskCaptured(TaskCaptured(taskID: TaskID("id-2"), title: "buy milk", viewID: .default))
        )
      ])
  }

  @Test("add understands the quick-capture syntax, same as the app")
  func addParsesTheQuickCaptureSyntax() throws {
    let cli = try CLIHarness()

    let result = cli.run("add", "call", "bank", "!a", "15m")

    #expect(result == CLIResult(exitCode: 0, output: "Captured id-2  call bank\n"))
    #expect(
      try cli.log().map(\.payload) == [
        .taskCaptured(TaskCaptured(taskID: TaskID("id-2"), title: "call bank", viewID: .default)),
        .taskPrioritized(TaskPrioritized(taskID: TaskID("id-2"), priority: .critical)),
        .taskEstimated(TaskEstimated(taskID: TaskID("id-2"), minutes: 15)),
      ])
  }

  @Test func addWithoutATitleIsAUsageError() throws {
    let cli = try CLIHarness()

    let result = cli.run("add", " ")

    #expect(result.exitCode == 64)
    #expect(result.error == "luthor: a task needs a title\n")
    #expect(try cli.log() == [])
  }
}

@Suite struct ListCommandTests {
  @Test func listShowsOpenTasksWithShortIDsInCaptureOrder() throws {
    let cli = try CLIHarness()
    try cli.seed([
      captured("0a1b2c3d-1111", "buy milk", lamport: 1),
      captured("9f8e7d6c-2222", "call mum", lamport: 2),
      captured("55555555-3333", "pay rent", lamport: 3),
      completed("9f8e7d6c-2222", lamport: 4),
    ])

    let result = cli.run("list")

    #expect(result == CLIResult(exitCode: 0, output: "0a1b2c3d  buy milk\n55555555  pay rent\n"))
  }

  @Test func listOfAnEmptyLogPrintsNothing() throws {
    let cli = try CLIHarness()

    #expect(cli.run("list") == CLIResult(exitCode: 0, output: ""))
  }
}

@Suite struct DoneCommandTests {
  @Test func doneCompletesTheTaskMatchingThePrefix() throws {
    let cli = try CLIHarness()
    try cli.seed([captured("0a1b2c3d-1111", "buy milk", lamport: 1)])

    let result = cli.run("done", "0a1")

    #expect(result == CLIResult(exitCode: 0, output: "Completed 0a1b2c3d  buy milk\n"))
    #expect(try cli.log().last == completed("0a1b2c3d-1111", id: "id-1", lamport: 2))
  }

  @Test func doneWithAnUnknownPrefixFails() throws {
    let cli = try CLIHarness()
    try cli.seed([captured("0a1b2c3d-1111", "buy milk")])

    let result = cli.run("done", "zz")

    #expect(result == CLIResult(exitCode: 1, error: "luthor: no open task matches 'zz'\n"))
    #expect(try cli.log().count == 1)
  }

  @Test func doneWithAnAmbiguousPrefixListsTheCandidates() throws {
    let cli = try CLIHarness()
    try cli.seed([
      captured("0a1b2c3d-1111", "buy milk", lamport: 1),
      captured("0a1fffff-2222", "call mum", lamport: 2),
    ])

    let result = cli.run("done", "0a1")

    #expect(
      result
        == CLIResult(
          exitCode: 1,
          error: "luthor: '0a1' matches more than one open task:\n0a1b2c3d  buy milk\n0a1fffff  call mum\n"
        ))
  }

  @Test func doneWithoutAPrefixIsAUsageError() throws {
    let cli = try CLIHarness()

    #expect(cli.run("done").exitCode == 64)
  }
}

@Suite struct CLIUsageTests {
  @Test(arguments: [[], ["frobnicate"]])
  func unknownOrMissingCommandPrintsUsage(arguments: [String]) throws {
    let cli = try CLIHarness()

    let result = CLI(environment: cli.environment, home: cli.home, ids: cli.ids).run(arguments)

    #expect(result.exitCode == 64)
    #expect(result.error.hasPrefix("usage: luthor"))
  }

  @Test(arguments: ["help", "--help", "-h"])
  func helpPrintsUsageToOutput(flag: String) throws {
    let cli = try CLIHarness()

    let result = cli.run(flag)

    #expect(result.exitCode == 0)
    #expect(result.output.hasPrefix("usage: luthor"))
  }

  @Test func logDefaultsToDotLuthorInHome() throws {
    let cli = try CLIHarness()
    cli.environment["LUTHOR_LOG"] = nil

    cli.run("add", "buy milk")

    let log = JSONLinesEventLog(fileURL: cli.home.appendingPathComponent(".luthor/events.jsonl"))
    #expect(try log.readAll().count == 1)
  }

  @Test func deviceIDDefaultsToLocal() throws {
    let cli = try CLIHarness()
    cli.environment["LUTHOR_DEVICE_ID"] = nil

    cli.run("add", "buy milk")

    #expect(try cli.log().map(\.deviceID) == [DeviceID("local")])
  }

  @Test func unreadableLogReportsTheLineAndLeavesTheFileAlone() throws {
    let cli = try CLIHarness()
    try Data("garbage\n".utf8).write(to: cli.logURL)

    let result = cli.run("add", "buy milk")

    #expect(result.exitCode == 1)
    #expect(result.error == "luthor: \(cli.logURL.path) line 1 is not a readable event\n")
    #expect(try Data(contentsOf: cli.logURL) == Data("garbage\n".utf8))
  }
}

@Suite("Given a Work view next to the default view")
struct CLIViewTests {
  static let log = [
    viewCreated("work", "Work", lamport: 1),
    captured("w1aaaaaa-1", "write the report", view: "work", lamport: 2),
    captured("d1aaaaaa-2", "buy milk", lamport: 3),
  ]

  @Test("add --view captures into the view it names, ignoring case")
  func addWithViewCapturesIntoThatView() throws {
    let cli = try CLIHarness()
    try cli.seed(Self.log)

    let result = cli.run("add", "--view", "work", "book", "a", "room")

    #expect(result == CLIResult(exitCode: 0, output: "Captured id-2  book a room\n"))
    #expect(try cli.log().last == captured("id-2", "book a room", id: "id-1", view: "work", lamport: 4))
  }

  @Test("add captures into LUTHOR_VIEW, and --view wins over it")
  func addUsesLuthorViewUnlessViewIsGiven() throws {
    let cli = try CLIHarness()
    try cli.seed(Self.log)
    cli.environment["LUTHOR_VIEW"] = "Work"

    cli.run("add", "book a room")
    cli.run("add", "--view", "Default", "call mum")

    #expect(
      try cli.log().suffix(2).map(\.payload) == [
        .taskCaptured(TaskCaptured(taskID: TaskID("id-2"), title: "book a room", viewID: ViewID("work"))),
        .taskCaptured(TaskCaptured(taskID: TaskID("id-4"), title: "call mum", viewID: .default)),
      ])
  }

  @Test("an unknown view is refused and nothing is written")
  func unknownViewIsRefused() throws {
    let cli = try CLIHarness()
    try cli.seed(Self.log)

    let result = cli.run("add", "--view", "Home", "buy milk")

    #expect(result == CLIResult(exitCode: 1, error: "luthor: no view named 'Home'\n"))
    #expect(try cli.log().count == 3)
  }

  @Test("--view without a name is a usage error", arguments: [["add", "--view"], ["list", "--view"]])
  func viewWithoutANameIsAUsageError(arguments: [String]) throws {
    let cli = try CLIHarness()

    #expect(CLI(environment: cli.environment, home: cli.home, ids: cli.ids).run(arguments).exitCode == 64)
  }

  @Test("list shows only the tasks of the view")
  func listShowsOnlyTheView() throws {
    let cli = try CLIHarness()
    try cli.seed(Self.log)

    #expect(cli.run("list") == CLIResult(exitCode: 0, output: "d1aaaaaa  buy milk\n"))
    #expect(cli.run("list", "--view", "Work") == CLIResult(exitCode: 0, output: "w1aaaaaa  write the report\n"))
  }

  @Test("done finds only tasks of the view")
  func doneStaysInTheView() throws {
    let cli = try CLIHarness()
    try cli.seed(Self.log)

    #expect(cli.run("done", "w1").exitCode == 1)
    #expect(
      cli.run("done", "--view", "Work", "w1")
        == CLIResult(exitCode: 0, output: "Completed w1aaaaaa  write the report\n"))
  }
}

@Suite("Given a default view chosen in settings")
struct CLIDefaultViewTests {
  @Test("add without --view or LUTHOR_VIEW captures into it")
  func addWithoutAViewUsesIt() throws {
    let cli = try CLIHarness()
    try cli.seed([
      viewCreated("work", "Work", lamport: 1),
      settingChanged(.defaultViewID, to: "work", lamport: 2),
    ])

    let result = cli.run("add", "book a room")

    #expect(result == CLIResult(exitCode: 0, output: "Captured id-2  book a room\n"))
    #expect(try cli.log().last == captured("id-2", "book a room", id: "id-1", view: "work", lamport: 3))
  }

  @Test("--view still wins over it")
  func explicitViewStillWins() throws {
    let cli = try CLIHarness()
    try cli.seed([
      viewCreated("work", "Work", lamport: 1),
      settingChanged(.defaultViewID, to: "work", lamport: 2),
    ])

    cli.run("add", "--view", "Default", "buy milk")

    #expect(try cli.log().last == captured("id-2", "buy milk", id: "id-1", lamport: 3))
  }

  @Test("a default view that no longer exists falls back to the built-in default view")
  func unknownDefaultViewFallsBack() throws {
    let cli = try CLIHarness()
    try cli.seed([settingChanged(.defaultViewID, to: "gone", lamport: 1)])

    cli.run("add", "buy milk")

    #expect(try cli.log().last == captured("id-2", "buy milk", id: "id-1", lamport: 2))
  }
}
