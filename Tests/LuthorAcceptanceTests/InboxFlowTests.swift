import Foundation
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given an empty inbox, when tasks are captured and one is completed")
struct InboxFlowTests {
  @Test("the list shows only the task still open")
  func listShowsOnlyTheOpenTask() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))

    library.capture("buy milk")
    library.capture("call mum")
    library.complete(try library.task("buy milk"))

    #expect(library.tasks.map(\.title) == ["call mum"])
  }
}
