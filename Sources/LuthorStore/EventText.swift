import Foundation
import LuthorDomain
import Yams

/// The log as readable YAML text, for a copy that does not depend on the app, and the way back in.
///
/// ```
/// format: 1
/// events:
///   - data: {…}
///     device: mac
///     id: …
///     lamport: 1
///     type: TaskCaptured
/// ```
///
/// Lossless: each entry is one event line of the log, with the same fields. An export of the frozen event
/// format therefore stays readable by every later build; a change to this layout bumps `formatVersion`.
public enum EventText {
  public static let formatVersion = 1

  /// The events in replay order. A line is JSON, which is YAML, so it is loaded as YAML to get typed values.
  public static func export(_ events: [EventEnvelope]) throws(EventLogError) -> String {
    var entries: [Any] = []
    for event in events.sorted(by: EventEnvelope.replayOrder) {
      let line = try EventLine.encode(event)
      do {
        if let entry = try Yams.load(yaml: line) { entries.append(entry) }
      } catch {
        throw .ioFailure("cannot export event \(event.id.rawValue): \(error)")
      }
    }
    do {
      let document: [String: Any] = ["format": formatVersion, "events": entries]
      return try Yams.dump(object: document, sortKeys: true)
    } catch {
      throw .ioFailure("cannot write the export: \(error)")
    }
  }

  /// The events in the text, except those of a type this build does not know. A text of a newer format, or
  /// one that is not an export, is an error.
  public static func events(from text: String) throws(EventLogError) -> [EventEnvelope] {
    let loaded: Any?
    do {
      loaded = try Yams.load(yaml: text)
    } catch {
      throw .ioFailure("not a readable export: \(error)")
    }
    guard let document = loaded as? [String: Any], let format = document["format"] as? Int else {
      throw .ioFailure("not an export: it has no format number")
    }
    guard format == formatVersion else {
      throw .ioFailure("export format \(format) is not supported; this build reads format \(formatVersion)")
    }
    guard let entries = document["events"] as? [Any] else { throw .ioFailure("not an export: it has no events") }
    var events: [EventEnvelope] = []
    for (index, entry) in entries.enumerated() {
      let line: String
      do {
        let data = try JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys])
        line = String(decoding: data, as: UTF8.self)
      } catch {
        throw .ioFailure("event \(index + 1) of the export is not readable: \(error)")
      }
      do {
        if let event = try EventLine.decodeIfKnown(line) { events.append(event) }
      } catch {
        throw .ioFailure("event \(index + 1) of the export is not a readable event")
      }
    }
    return events
  }
}
