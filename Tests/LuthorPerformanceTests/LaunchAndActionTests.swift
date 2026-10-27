import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// How long `work` takes, in milliseconds.
private func milliseconds(_ work: () -> Void) -> Double {
  let clock = ContinuousClock()
  let elapsed = clock.measure(work)
  return Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
}

private func median(_ values: [Double]) -> Double {
  values.sorted()[values.count / 2]
}

/// Prints a line `make bench` and the CI log show, so the numbers are on record before a budget is set from them.
private func report(_ name: String, _ millis: Double) {
  print("BENCH \(name): \(String(format: "%.1f", millis)) ms")
}

@MainActor
private func launch(on url: URL) -> LibraryViewModel {
  let library = LibraryViewModel(
    log: JSONLinesEventLog(fileURL: url),
    commands: Commands(deviceID: DeviceID("mac"), ids: UUIDGenerator()),
    today: { date("2026-10-19") })
  library.reload()
  return library
}

/// The budgets are loose, to catch an order of magnitude and not noise on a debug build in CI; they are tightened
/// from the numbers the first runs print.
@MainActor
@Suite("When the log holds years of heavy use")
struct LaunchAndActionTests {
  static let launchBudgetMilliseconds = 20_000.0
  static let actionBudgetMilliseconds = 2_000.0

  @Test("launch and actions cost what the budget allows", arguments: [1, 3, 5])
  func launchAndActions(years: Int) throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let url = dir.file("events.jsonl")
    let log = JSONLinesEventLog(fileURL: url)
    let events = syntheticLog(years: years)
    try log.append(events)
    print("BENCH \(years) years: \(events.count) events, \((try? Data(contentsOf: url).count) ?? 0) bytes")

    var decoded: [EventEnvelope] = []
    report("\(years)y read and decode", milliseconds { decoded = (try? log.readAll()) ?? [] })
    #expect(decoded.count == events.count)
    report("\(years)y replay", milliseconds { _ = LibraryState.replay(decoded) })

    var library: LibraryViewModel?
    let launched = milliseconds { library = launch(on: url) }
    report("\(years)y cold launch", launched)
    let window = try #require(library)
    #expect(launched < Self.launchBudgetMilliseconds)

    let captures = (0..<20).map { index in milliseconds { window.capture("Benchmark task \(index)") } }
    report("\(years)y capture, median of 20", median(captures))
    #expect(median(captures) < Self.actionBudgetMilliseconds)

    let reloads = (0..<5).map { _ in milliseconds { window.reload() } }
    report("\(years)y reload of an unchanged log, median of 5", median(reloads))
    #expect(median(reloads) < Self.launchBudgetMilliseconds)
  }
}

extension LibraryViewModel {
  /// Types a title into the capture field and presses Return.
  fileprivate func capture(_ title: String) {
    draft = title
    submit()
  }
}
