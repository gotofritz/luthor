import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// A log that reports one damaged line until it is quarantined.
private final class DamagedLog: EventLog, @unchecked Sendable {
  var damaged = true
  let events = [captured("t1", "buy milk", lamport: 1)]

  func readAll() throws(EventLogError) -> [EventEnvelope] {
    if damaged { throw .unreadableLine(2) }
    return events
  }
  func append(_ events: [EventEnvelope]) throws(EventLogError) {}
  func readReportingProblems() throws(EventLogError) -> LogReading {
    LogReading(events: events, problems: damaged ? [LogProblem(file: "events.jsonl", line: 2)] : [])
  }
  func quarantineUnreadableLines() throws(EventLogError) -> Int {
    defer { damaged = false }
    return damaged ? 1 : 0
  }
}

@MainActor
private func makeLibrary() -> LibraryViewModel {
  LibraryViewModel(
    log: DamagedLog(), commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
    today: { date("2026-10-19") })
}

@MainActor
@Suite("When the log has a damaged line")
struct DamagedLogViewModelTests {
  @Test("the window opens with the readable tasks and says what was left out")
  func opensAndReports() {
    let library = makeLibrary()

    library.reload()

    #expect(library.tasks.map(\.title) == ["buy milk"])
    #expect(library.errorMessage == nil)
    #expect(library.logProblemsMessage?.contains("line 2 of events.jsonl") == true)
  }

  @Test("repairing clears the message")
  func repairingClearsTheMessage() {
    let library = makeLibrary()
    library.reload()

    library.repairLog()

    #expect(library.logProblemsMessage == nil)
    #expect(library.tasks.map(\.title) == ["buy milk"])
  }
}
