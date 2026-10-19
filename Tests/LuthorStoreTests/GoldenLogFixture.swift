import Foundation

/// A synthetic event log, frozen with the event format (`Fixtures/golden-log.jsonl`): one line for every event
/// type, with every optional field present on some line. It must always decode and replay. A change that breaks
/// it breaks old logs, so fix the change, never the file. A new event type adds a line to it.
enum GoldenLogFixture {
  static var lines: [String] {
    get throws {
      guard let url = Bundle.module.url(forResource: "golden-log", withExtension: "jsonl", subdirectory: "Fixtures")
      else { throw CocoaError(.fileNoSuchFile) }
      return try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
    }
  }
}
