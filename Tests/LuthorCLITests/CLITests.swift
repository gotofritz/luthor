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

  deinit { dir.remove() }

  @discardableResult
  func run(_ arguments: String...) -> CLIResult {
    CLI(environment: environment, ids: ids).run(arguments)
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
          payload: .taskCaptured(TaskCaptured(taskID: TaskID("id-2"), title: "buy milk"))
        )
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

    let result = CLI(environment: cli.environment, ids: cli.ids).run(arguments)

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

  @Test func missingLogPathIsAConfigurationError() throws {
    let cli = try CLIHarness()
    cli.environment["LUTHOR_LOG"] = nil

    let result = cli.run("list")

    #expect(result == CLIResult(exitCode: 78, error: "luthor: set LUTHOR_LOG to the path of the event log\n"))
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
