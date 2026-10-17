import Foundation
import LuthorDomain

#if canImport(Glibc)
  import Glibc
#elseif canImport(Darwin)
  import Darwin
#endif

public enum EventLogError: Error, Equatable {
  /// The 1-based line could not be decoded as an event.
  case unreadableLine(Int)
  case ioFailure(String)
}

/// Encodes one event as one line of JSON:
/// `{"data":{…},"device":"…","id":"…","lamport":1,"type":"TaskCaptured"}`.
public enum EventLine {
  public static func encode(_ event: EventEnvelope) throws(EventLogError) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    do {
      if let line = String(bytes: try encoder.encode(EventLineDTO(event)), encoding: .utf8) { return line }
    } catch {
      throw .ioFailure("cannot encode event \(event.id.rawValue): \(error)")
    }
    throw .ioFailure("cannot encode event \(event.id.rawValue) as UTF-8")
  }

  /// Throws `unreadableLine(0)`; callers that know the line number replace it.
  public static func decode(_ line: String) throws(EventLogError) -> EventEnvelope {
    do {
      return try JSONDecoder().decode(EventLineDTO.self, from: Data(line.utf8)).event
    } catch {
      throw .unreadableLine(0)
    }
  }
}

/// The on-disk shape of one event line.
private struct EventLineDTO: Codable {
  let event: EventEnvelope

  init(_ event: EventEnvelope) {
    self.event = event
  }

  private enum CodingKeys: String, CodingKey {
    case type, id, device, lamport, data
  }

  private enum EventType: String, Codable {
    case taskCaptured = "TaskCaptured"
    case taskCompleted = "TaskCompleted"
    case projectCreated = "ProjectCreated"
    case taskMovedToProject = "TaskMovedToProject"
    case projectCompleted = "ProjectCompleted"
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let payload: EventPayload =
      switch try container.decode(EventType.self, forKey: .type) {
      case .taskCaptured: .taskCaptured(try container.decode(TaskCaptured.self, forKey: .data))
      case .taskCompleted: .taskCompleted(try container.decode(TaskCompleted.self, forKey: .data))
      case .projectCreated: .projectCreated(try container.decode(ProjectCreated.self, forKey: .data))
      case .taskMovedToProject: .taskMovedToProject(try container.decode(TaskMovedToProject.self, forKey: .data))
      case .projectCompleted: .projectCompleted(try container.decode(ProjectCompleted.self, forKey: .data))
      }
    event = EventEnvelope(
      id: try container.decode(EventID.self, forKey: .id),
      deviceID: try container.decode(DeviceID.self, forKey: .device),
      lamport: try container.decode(UInt64.self, forKey: .lamport),
      payload: payload
    )
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(event.id, forKey: .id)
    try container.encode(event.deviceID, forKey: .device)
    try container.encode(event.lamport, forKey: .lamport)
    switch event.payload {
    case .taskCaptured(let data):
      try container.encode(EventType.taskCaptured, forKey: .type)
      try container.encode(data, forKey: .data)
    case .taskCompleted(let data):
      try container.encode(EventType.taskCompleted, forKey: .type)
      try container.encode(data, forKey: .data)
    case .projectCreated(let data):
      try container.encode(EventType.projectCreated, forKey: .type)
      try container.encode(data, forKey: .data)
    case .taskMovedToProject(let data):
      try container.encode(EventType.taskMovedToProject, forKey: .type)
      try container.encode(data, forKey: .data)
    case .projectCompleted(let data):
      try container.encode(EventType.projectCompleted, forKey: .type)
      try container.encode(data, forKey: .data)
    }
  }
}

/// The canonical event log: one JSON object per line, append-only.
public struct JSONLinesEventLog: Sendable {
  public let fileURL: URL

  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  /// All events in file order. A missing file is an empty log.
  public func readAll() throws(EventLogError) -> [EventEnvelope] {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
    let contents: String
    do {
      contents = try String(contentsOf: fileURL, encoding: .utf8)
    } catch {
      throw .ioFailure("cannot read \(fileURL.path): \(error)")
    }
    var events: [EventEnvelope] = []
    for (index, line) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
    where !line.allSatisfy(\.isWhitespace) {
      do {
        events.append(try EventLine.decode(String(line)))
      } catch {
        throw .unreadableLine(index + 1)
      }
    }
    return events
  }

  /// Appends the events in one `write`, with `O_APPEND`, so existing bytes are never rewritten.
  public func append(_ events: [EventEnvelope]) throws(EventLogError) {
    guard !events.isEmpty else { return }
    var text = ""
    for event in events {
      text += try EventLine.encode(event) + "\n"
    }
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    } catch {
      throw .ioFailure("cannot create directory for \(fileURL.path): \(error)")
    }
    let descriptor = open(fileURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o600)
    guard descriptor >= 0 else { throw .ioFailure("cannot open \(fileURL.path): errno \(errno)") }
    defer { close(descriptor) }
    let bytes = Array(text.utf8)
    let written = bytes.withUnsafeBytes { write(descriptor, $0.baseAddress, $0.count) }
    guard written == bytes.count else {
      throw .ioFailure("short write to \(fileURL.path): \(written) of \(bytes.count) bytes, errno \(errno)")
    }
  }
}
