import Foundation
import LuthorCLI
import LuthorTestSupport
import Testing

@Suite("Given an empty inbox, when tasks are captured and one is completed")
struct InboxFlowTests {
  @Test("the list shows only the task still open")
  func listShowsOnlyTheOpenTask() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let cli = CLI(
      environment: ["LUTHOR_LOG": dir.file("events.jsonl").path, "LUTHOR_DEVICE_ID": "mac"],
      home: dir.file("home"),
      ids: SequentialIDs()
    )

    #expect(cli.run(["add", "buy", "milk"]) == CLIResult(exitCode: 0, output: "Captured id-2  buy milk\n"))
    #expect(cli.run(["add", "call", "mum"]) == CLIResult(exitCode: 0, output: "Captured id-4  call mum\n"))
    #expect(cli.run(["done", "id-2"]) == CLIResult(exitCode: 0, output: "Completed id-2  buy milk\n"))
    #expect(cli.run(["list"]) == CLIResult(exitCode: 0, output: "id-4  call mum\n"))
  }
}
