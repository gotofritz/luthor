import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// A log that notes where it is read, and can hold a read, after it has read, until told to go on.
private final class WatchedLog: EventLog, @unchecked Sendable {
  private let lock = NSLock()
  private let gate = DispatchSemaphore(value: 0)
  private var readOnMain = false
  private var holding = false
  private var held = false
  let base: DeviceFilesEventLog

  init(_ base: DeviceFilesEventLog) {
    self.base = base
  }

  var wasReadOnMainThread: Bool { lock.withLock { readOnMain } }
  var isHoldingARead: Bool { lock.withLock { held } }

  /// Forgets where the log was read so far, such as by the first read of a window.
  func forgetReads() { lock.withLock { readOnMain = false } }

  /// The next full read waits in `readReportingProblems`, with what it read, until `release()`.
  func holdNextRead() { lock.withLock { holding = true } }
  func release() { gate.signal() }

  func readAll() throws(EventLogError) -> [EventEnvelope] { try base.readAll() }

  func readReportingProblems() throws(EventLogError) -> LogReading {
    let shouldHold = lock.withLock {
      if Thread.isMainThread { readOnMain = true }
      defer { holding = false }
      return holding
    }
    let reading = try base.readReportingProblems()
    if shouldHold {
      lock.withLock { held = true }
      gate.wait()
    }
    return reading
  }

  func readIncrement(since cursor: LogCursor) throws(EventLogError) -> LogReading? {
    lock.withLock { if Thread.isMainThread { readOnMain = true } }
    return try base.readIncrement(since: cursor)
  }

  func changeToken() -> String? { base.changeToken() }
  func append(_ events: [EventEnvelope]) throws(EventLogError) { try base.append(events) }
}

private struct Setup {
  let library: LibraryViewModel
  let log: WatchedLog
  let air: DeviceFilesEventLog
}

@MainActor
private func makeLibrary(_ dir: TemporaryDirectory) throws -> Setup {
  let air = DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("air"))
  try air.append([captured("t1", "buy milk", device: "air", lamport: 1)])
  let log = WatchedLog(DeviceFilesEventLog(directory: dir.url, deviceID: DeviceID("mac")))
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()),
    today: { date("2026-10-19") })
  library.reload()
  return Setup(library: library, log: log, air: air)
}

@MainActor
@Suite("When the log is reloaded in the background")
struct BackgroundReloadViewModelTests {
  @Test("an event another device appended is shown, and the log was not read on the main thread")
  func outsideEventIsShownFromAnotherThread() async throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let setup = try makeLibrary(dir)
    try setup.air.append([captured("t2", "call mum", device: "air", lamport: 2)])
    setup.log.forgetReads()

    await setup.library.reloadInBackground()

    #expect(setup.library.tasks.map(\.title) == ["buy milk", "call mum"])
    #expect(!setup.log.wasReadOnMainThread)
  }

  @Test("an action taken while the log is being read is not lost")
  func actionDuringTheReadIsKept() async throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let setup = try makeLibrary(dir)
    try setup.air.append([captured("t2", "call mum", device: "air", lamport: 2)])
    // Another device replaced its file, so the read has to be a full one, and it waits.
    setup.log.holdNextRead()
    let line = try EventLine.encode(captured("t1", "buy milk", device: "air", lamport: 1))
    let more = try EventLine.encode(captured("t2", "call mum", device: "air", lamport: 2))
    try (more + "\n" + line + "\n").write(
      to: dir.file("events-air.jsonl"), atomically: true, encoding: .utf8)

    let reload = Task { await setup.library.reloadInBackground() }
    while !setup.log.isHoldingARead { await Task.yield() }
    setup.library.draft = "pay rent"
    setup.library.submit()
    setup.log.release()
    await reload.value

    #expect(Set(setup.library.tasks.map(\.title)) == ["buy milk", "call mum", "pay rent"])
  }
}
