import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// A log that counts how it is read.
private final class CountingLog: EventLog, @unchecked Sendable {
  let base: DeviceFilesEventLog
  private(set) var fullReads = 0
  private(set) var increments = 0

  init(_ base: DeviceFilesEventLog) {
    self.base = base
  }

  func readAll() throws(EventLogError) -> [EventEnvelope] { try base.readAll() }

  func readReportingProblems() throws(EventLogError) -> LogReading {
    fullReads += 1
    return try base.readReportingProblems()
  }

  func readIncrement(since cursor: LogCursor) throws(EventLogError) -> LogReading? {
    increments += 1
    return try base.readIncrement(since: cursor)
  }

  func changeToken() -> String? { base.changeToken() }
  func append(_ events: [EventEnvelope]) throws(EventLogError) { try base.append(events) }
}

private struct Setup {
  let library: LibraryViewModel
  let log: CountingLog
  let air: DeviceFilesEventLog
}

@MainActor
private func makeLibrary(_ dir: TemporaryDirectory, first: [EventEnvelope] = []) throws -> Setup {
  let air = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("air"))
  try air.append(first)
  let log = CountingLog(DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac")))
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
    today: { date("2026-10-19") })
  library.reload()
  return Setup(library: library, log: log, air: air)
}

@MainActor
@Suite("When another device appends to the shared folder")
struct IncrementalReloadViewModelTests {
  @Test("reloading shows its events without reading the log from the start again")
  func reloadReadsOnlyTheNewEvents() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let setup = try makeLibrary(dir, first: [captured("t1", "buy milk", device: "air", lamport: 1)])

    try setup.air.append([captured("t2", "call mum", device: "air", lamport: 2)])
    setup.library.reload()

    #expect(setup.library.tasks.map(\.title) == ["buy milk", "call mum"])
    #expect(setup.log.fullReads == 1)
    #expect(setup.log.increments == 1)
  }

  @Test("an event that sorts before one already applied is put in its place")
  func olderEventIsPutInPlace() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let setup = try makeLibrary(
      dir,
      first: [
        captured("t1", "buy milk", device: "air", lamport: 1),
        renamed("t1", to: "late name", device: "air", lamport: 5),
      ])

    try setup.air.append([renamed("t1", to: "early name", id: "early", device: "air", lamport: 3)])
    setup.library.reload()

    #expect(setup.library.tasks.map(\.title) == ["late name"])
  }

  @Test("an event written here and then seen in the file is applied once")
  func ownEventIsAppliedOnce() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let setup = try makeLibrary(dir)
    setup.library.draft = "buy milk"
    setup.library.submit()

    try setup.air.append([captured("t2", "call mum", device: "air", lamport: 20)])
    setup.library.reload()

    #expect(setup.library.tasks.map(\.title) == ["buy milk", "call mum"])
  }

  @Test("a file that was replaced is read again from the start")
  func replacedFileIsReadWhole() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let setup = try makeLibrary(dir, first: [captured("t1", "buy milk", device: "air", lamport: 1)])

    let line = try EventLine.encode(captured("t9", "something else entirely", device: "air", lamport: 2))
    try (line + "\n").write(to: dir.file("events-air.jsonl"), atomically: true, encoding: .utf8)
    setup.library.reload()

    #expect(setup.library.tasks.map(\.title) == ["something else entirely"])
    #expect(setup.log.fullReads == 2)
  }
}
