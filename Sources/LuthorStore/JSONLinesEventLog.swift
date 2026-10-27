import Foundation
import LuthorDomain

#if canImport(Glibc)
  import Glibc
#elseif canImport(Darwin)
  import Darwin
#endif

/// A line of a log that is not an event; `line` is 1-based.
public struct LogProblem: Equatable, Sendable {
  public let file: String
  public let line: Int

  public init(file: String, line: Int) {
    self.file = file
    self.line = line
  }
}

/// What a log holds: the events that could be read, and the lines that could not.
public struct LogReading: Sendable {
  public var events: [EventEnvelope] = []
  public var problems: [LogProblem] = []

  public init(events: [EventEnvelope] = [], problems: [LogProblem] = []) {
    self.events = events
    self.problems = problems
  }
}

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

  /// Every event type this build understands, as written in the `type` field. The frozen event format: a type
  /// is only ever added to this list, never renamed or removed.
  public static var knownTypes: [String] { EventLineDTO.EventType.allCases.map(\.rawValue) }

  /// Throws `unreadableLine(0)`; callers that know the line number replace it. Also throws for an event of a
  /// type this build does not know; `decodeIfKnown` is the reader that skips those.
  public static func decode(_ line: String) throws(EventLogError) -> EventEnvelope {
    do {
      return try JSONDecoder().decode(EventLineDTO.self, from: Data(line.utf8)).event
    } catch {
      throw .unreadableLine(0)
    }
  }

  /// Like `decode`, but `nil` for a well-formed line whose `type` this build does not know, written by a newer
  /// build. The caller skips it and leaves it in the log. A line that is not JSON, or lacks a `type`, still
  /// throws `unreadableLine(0)`.
  public static func decodeIfKnown(_ line: String) throws(EventLogError) -> EventEnvelope? {
    let probe: EventTypeProbe
    let decoder = JSONDecoder()
    do {
      probe = try decoder.decode(EventTypeProbe.self, from: Data(line.utf8))
    } catch {
      throw .unreadableLine(0)
    }
    guard EventLineDTO.EventType(rawValue: probe.type) != nil else { return nil }
    do {
      return try decoder.decode(EventLineDTO.self, from: Data(line.utf8)).event
    } catch {
      throw .unreadableLine(0)
    }
  }
}

/// Just the `type` of a line, to tell an unknown event from a damaged line.
private struct EventTypeProbe: Decodable {
  let type: String
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

  fileprivate enum EventType: String, Codable, CaseIterable {
    case taskCaptured = "TaskCaptured"
    case taskCompleted = "TaskCompleted"
    case taskReopened = "TaskReopened"
    case taskRenamed = "TaskRenamed"
    case taskNoted = "TaskNoted"
    case taskKindChanged = "TaskKindChanged"
    case taskMoved = "TaskMoved"
    case viewCreated = "ViewCreated"
    case viewRenamed = "ViewRenamed"
    case taskMovedToView = "TaskMovedToView"
    case taskPrioritized = "TaskPrioritized"
    case taskEstimated = "TaskEstimated"
    case settingChanged = "SettingChanged"
    case taskScheduled = "TaskScheduled"
    case taskUnscheduled = "TaskUnscheduled"
    case dayPlanOrdered = "DayPlanOrdered"
    case dayCapacitySet = "DayCapacitySet"
    case dayHoursSet = "DayHoursSet"
    case taskStartSet = "TaskStartSet"
    case dayBlockSet = "DayBlockSet"
    case dayBlockRemoved = "DayBlockRemoved"
    case taskSessionSet = "TaskSessionSet"
    case taskSessionRemoved = "TaskSessionRemoved"
    case taskDelegated = "TaskDelegated"
    case taskReclaimed = "TaskReclaimed"
    case taskDropped = "TaskDropped"
    case taskDueSet = "TaskDueSet"
    case tagCreated = "TagCreated"
    case taskTagged = "TaskTagged"
    case taskUntagged = "TaskUntagged"
    case taskTimeLogged = "TaskTimeLogged"
    case unplannedTimeLogged = "UnplannedTimeLogged"
    case dayReviewed = "DayReviewed"
    case reviewDefaultSet = "ReviewDefaultSet"
    case reviewIntervalSet = "ReviewIntervalSet"
    case reviewDateSet = "ReviewDateSet"
    case taskReviewed = "TaskReviewed"
    case taskRepeatSet = "TaskRepeatSet"
    case taskRecurred = "TaskRecurred"
    case taskDuplicated = "TaskDuplicated"
    case taskDeleted = "TaskDeleted"
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(EventType.self, forKey: .type)
    let payload: EventPayload =
      switch type {
      case .taskCaptured: .taskCaptured(try container.decode(TaskCaptured.self, forKey: .data))
      case .taskCompleted: .taskCompleted(try container.decode(TaskCompleted.self, forKey: .data))
      case .taskReopened: .taskReopened(try container.decode(TaskReopened.self, forKey: .data))
      case .taskRenamed: .taskRenamed(try container.decode(TaskRenamed.self, forKey: .data))
      case .taskNoted: .taskNoted(try container.decode(TaskNoted.self, forKey: .data))
      case .taskKindChanged: .taskKindChanged(try container.decode(TaskKindChanged.self, forKey: .data))
      case .taskMoved: .taskMoved(try container.decode(TaskMoved.self, forKey: .data))
      case .viewCreated: .viewCreated(try container.decode(ViewCreated.self, forKey: .data))
      case .viewRenamed: .viewRenamed(try container.decode(ViewRenamed.self, forKey: .data))
      case .taskMovedToView: .taskMovedToView(try container.decode(TaskMovedToView.self, forKey: .data))
      case .taskPrioritized: .taskPrioritized(try container.decode(TaskPrioritized.self, forKey: .data))
      case .taskEstimated: .taskEstimated(try container.decode(TaskEstimated.self, forKey: .data))
      case .settingChanged: .settingChanged(try container.decode(SettingChanged.self, forKey: .data))
      case .taskScheduled: .taskScheduled(try container.decode(TaskScheduled.self, forKey: .data))
      case .taskUnscheduled: .taskUnscheduled(try container.decode(TaskUnscheduled.self, forKey: .data))
      case .dayPlanOrdered: .dayPlanOrdered(try container.decode(DayPlanOrdered.self, forKey: .data))
      case .dayCapacitySet: .dayCapacitySet(try container.decode(DayCapacitySet.self, forKey: .data))
      case .dayHoursSet: .dayHoursSet(try container.decode(DayHoursSet.self, forKey: .data))
      case .taskStartSet: .taskStartSet(try container.decode(TaskStartSet.self, forKey: .data))
      case .dayBlockSet: .dayBlockSet(try container.decode(DayBlockSet.self, forKey: .data))
      case .dayBlockRemoved: .dayBlockRemoved(try container.decode(DayBlockRemoved.self, forKey: .data))
      case .taskSessionSet: .taskSessionSet(try container.decode(TaskSessionSet.self, forKey: .data))
      case .taskSessionRemoved: .taskSessionRemoved(try container.decode(TaskSessionRemoved.self, forKey: .data))
      case .taskDelegated: .taskDelegated(try container.decode(TaskDelegated.self, forKey: .data))
      case .taskReclaimed: .taskReclaimed(try container.decode(TaskReclaimed.self, forKey: .data))
      case .taskDropped: .taskDropped(try container.decode(TaskDropped.self, forKey: .data))
      case .taskDueSet: .taskDueSet(try container.decode(TaskDueSet.self, forKey: .data))
      case .tagCreated: .tagCreated(try container.decode(TagCreated.self, forKey: .data))
      case .taskTagged: .taskTagged(try container.decode(TaskTagged.self, forKey: .data))
      case .taskUntagged: .taskUntagged(try container.decode(TaskUntagged.self, forKey: .data))
      case .taskTimeLogged, .unplannedTimeLogged, .dayReviewed, .reviewDefaultSet, .reviewIntervalSet,
        .reviewDateSet, .taskReviewed, .taskRepeatSet, .taskRecurred, .taskDuplicated, .taskDeleted:
        try Self.laterPayload(type, in: container)
      }
    event = EventEnvelope(
      id: try container.decode(EventID.self, forKey: .id),
      deviceID: try container.decode(DeviceID.self, forKey: .device),
      lamport: try container.decode(UInt64.self, forKey: .lamport),
      payload: payload
    )
  }

  /// The payload of a review event, the daily or the weekly one, or of a repeat or structure event. Split from
  /// `init(from:)` (SwiftLint function_body_length) rather than suppressed.
  private static func laterPayload(
    _ type: EventType,
    in container: KeyedDecodingContainer<CodingKeys>
  ) throws -> EventPayload {
    switch type {
    case .taskTimeLogged: .taskTimeLogged(try container.decode(TaskTimeLogged.self, forKey: .data))
    case .unplannedTimeLogged: .unplannedTimeLogged(try container.decode(UnplannedTimeLogged.self, forKey: .data))
    case .dayReviewed: .dayReviewed(try container.decode(DayReviewed.self, forKey: .data))
    case .reviewDefaultSet: .reviewDefaultSet(try container.decode(ReviewDefaultSet.self, forKey: .data))
    case .reviewIntervalSet: .reviewIntervalSet(try container.decode(ReviewIntervalSet.self, forKey: .data))
    case .reviewDateSet: .reviewDateSet(try container.decode(ReviewDateSet.self, forKey: .data))
    case .taskReviewed: .taskReviewed(try container.decode(TaskReviewed.self, forKey: .data))
    case .taskRepeatSet: .taskRepeatSet(try container.decode(TaskRepeatSet.self, forKey: .data))
    case .taskRecurred: .taskRecurred(try container.decode(TaskRecurred.self, forKey: .data))
    case .taskDuplicated: .taskDuplicated(try container.decode(TaskDuplicated.self, forKey: .data))
    case .taskDeleted: .taskDeleted(try container.decode(TaskDeleted.self, forKey: .data))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type, in: container, debugDescription: "not a later event: \(type.rawValue)")
    }
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(event.id, forKey: .id)
    try container.encode(event.deviceID, forKey: .device)
    try container.encode(event.lamport, forKey: .lamport)
    switch event.payload {
    case .taskCaptured(let data): try write(.taskCaptured, data, to: &container)
    case .taskCompleted(let data): try write(.taskCompleted, data, to: &container)
    case .taskReopened(let data): try write(.taskReopened, data, to: &container)
    case .taskRenamed(let data): try write(.taskRenamed, data, to: &container)
    case .taskNoted(let data): try write(.taskNoted, data, to: &container)
    case .taskKindChanged(let data): try write(.taskKindChanged, data, to: &container)
    case .taskMoved(let data): try write(.taskMoved, data, to: &container)
    case .viewCreated(let data): try write(.viewCreated, data, to: &container)
    case .viewRenamed(let data): try write(.viewRenamed, data, to: &container)
    case .taskMovedToView(let data): try write(.taskMovedToView, data, to: &container)
    case .taskPrioritized(let data): try write(.taskPrioritized, data, to: &container)
    case .taskEstimated(let data): try write(.taskEstimated, data, to: &container)
    case .settingChanged(let data): try write(.settingChanged, data, to: &container)
    case .taskScheduled(let data): try write(.taskScheduled, data, to: &container)
    case .taskUnscheduled(let data): try write(.taskUnscheduled, data, to: &container)
    case .dayPlanOrdered(let data): try write(.dayPlanOrdered, data, to: &container)
    case .dayCapacitySet(let data): try write(.dayCapacitySet, data, to: &container)
    case .dayHoursSet(let data): try write(.dayHoursSet, data, to: &container)
    case .taskStartSet(let data): try write(.taskStartSet, data, to: &container)
    case .dayBlockSet(let data): try write(.dayBlockSet, data, to: &container)
    case .dayBlockRemoved(let data): try write(.dayBlockRemoved, data, to: &container)
    case .taskSessionSet(let data): try write(.taskSessionSet, data, to: &container)
    case .taskSessionRemoved(let data): try write(.taskSessionRemoved, data, to: &container)
    case .taskDelegated(let data): try write(.taskDelegated, data, to: &container)
    case .taskReclaimed(let data): try write(.taskReclaimed, data, to: &container)
    case .taskDropped(let data): try write(.taskDropped, data, to: &container)
    case .taskDueSet(let data): try write(.taskDueSet, data, to: &container)
    case .tagCreated(let data): try write(.tagCreated, data, to: &container)
    case .taskTagged(let data): try write(.taskTagged, data, to: &container)
    case .taskUntagged(let data): try write(.taskUntagged, data, to: &container)
    case .taskTimeLogged(let data): try write(.taskTimeLogged, data, to: &container)
    case .unplannedTimeLogged(let data): try write(.unplannedTimeLogged, data, to: &container)
    case .dayReviewed(let data): try write(.dayReviewed, data, to: &container)
    case .reviewDefaultSet(let data): try write(.reviewDefaultSet, data, to: &container)
    case .reviewIntervalSet(let data): try write(.reviewIntervalSet, data, to: &container)
    case .reviewDateSet(let data): try write(.reviewDateSet, data, to: &container)
    case .taskReviewed(let data): try write(.taskReviewed, data, to: &container)
    case .taskRepeatSet(let data): try write(.taskRepeatSet, data, to: &container)
    case .taskRecurred(let data): try write(.taskRecurred, data, to: &container)
    case .taskDuplicated(let data): try write(.taskDuplicated, data, to: &container)
    case .taskDeleted(let data): try write(.taskDeleted, data, to: &container)
    }
  }

  /// Writes the event's type and its payload.
  private func write(
    _ type: EventType,
    _ data: some Encodable,
    to container: inout KeyedEncodingContainer<CodingKeys>
  ) throws {
    try container.encode(type, forKey: .type)
    try container.encode(data, forKey: .data)
  }
}

/// The canonical event log: one JSON object per line, append-only.
public struct JSONLinesEventLog: Sendable {
  public let fileURL: URL

  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  /// All events in file order, except those of a type this build does not know (a newer build wrote them);
  /// they stay in the file untouched. A missing file is an empty log.
  public func readAll() throws(EventLogError) -> [EventEnvelope] {
    try readAll(skippingIncompleteTail: false)
  }

  /// All events in file order. A missing file is an empty log.
  ///
  /// With `skippingIncompleteTail`, a last line that has no newline yet and cannot be decoded is left out
  /// instead of being an error: another device's file whose sync is still in progress.
  public func readAll(skippingIncompleteTail: Bool) throws(EventLogError) -> [EventEnvelope] {
    let reading = try readReportingProblems(skippingIncompleteTail: skippingIncompleteTail)
    if let first = reading.problems.first { throw .unreadableLine(first.line) }
    return reading.events
  }

  /// The readable events, and every line that is not one, instead of failing at the first. Bad lines stay in
  /// the file. See `readAll(skippingIncompleteTail:)` for the option.
  public func readReportingProblems(skippingIncompleteTail: Bool) throws(EventLogError) -> LogReading {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return LogReading() }
    let lines = try readLines()
    var reading = LogReading()
    for (index, line) in lines.enumerated() where !line.allSatisfy(\.isWhitespace) {
      do {
        if let event = try EventLine.decodeIfKnown(String(line)) { reading.events.append(event) }
      } catch {
        // The last element has no newline after it; earlier ones always do.
        if skippingIncompleteTail && index == lines.count - 1 { break }
        reading.problems.append(LogProblem(file: fileURL.lastPathComponent, line: index + 1))
      }
    }
    return reading
  }

  /// Moves every line that is not an event into `<file>.rejected` and rewrites the file without them. Lines of
  /// an unknown event type are not damaged and stay. Returns how many lines moved; a clean file is untouched.
  public func quarantineUnreadableLines() throws(EventLogError) -> Int {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return 0 }
    var kept: [Substring] = []
    var rejected: [Substring] = []
    for line in try readLines() where !line.allSatisfy(\.isWhitespace) {
      do {
        _ = try EventLine.decodeIfKnown(String(line))
        kept.append(line)
      } catch {
        rejected.append(line)
      }
    }
    guard !rejected.isEmpty else { return 0 }
    let rejectedURL = fileURL.appendingPathExtension("rejected")
    try JSONLinesEventLog.appendText(rejected.map { String($0) + "\n" }.joined(), to: rejectedURL)
    do {
      try kept.map { String($0) + "\n" }.joined().write(to: fileURL, atomically: true, encoding: .utf8)
    } catch {
      throw .ioFailure("cannot rewrite \(fileURL.path): \(error)")
    }
    return rejected.count
  }

  private func readLines() throws(EventLogError) -> [Substring] {
    do {
      return try String(contentsOf: fileURL, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
    } catch {
      throw .ioFailure("cannot read \(fileURL.path): \(error)")
    }
  }

  /// Appends the events in one `write`, with `O_APPEND`, so existing bytes are never rewritten. If the file
  /// does not end in a newline (a write cut short), the first event starts on a fresh line, so a torn
  /// fragment never swallows it. The write is flushed to disk before returning.
  public func append(_ events: [EventEnvelope]) throws(EventLogError) {
    guard !events.isEmpty else { return }
    var text = ""
    for event in events {
      text += try EventLine.encode(event) + "\n"
    }
    try Self.appendText(text, to: fileURL, startingOnAFreshLine: true)
  }

  private static func appendText(
    _ text: String, to url: URL, startingOnAFreshLine: Bool = false
  ) throws(EventLogError) {
    do {
      try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    } catch {
      throw .ioFailure("cannot create directory for \(url.path): \(error)")
    }
    let descriptor = open(url.path, O_RDWR | O_APPEND | O_CREAT, 0o600)
    guard descriptor >= 0 else { throw .ioFailure("cannot open \(url.path): errno \(errno)") }
    defer { close(descriptor) }
    var bytes = Array(text.utf8)
    if startingOnAFreshLine {
      var last: UInt8 = 0x0A
      let size = lseek(descriptor, 0, SEEK_END)
      if size > 0, pread(descriptor, &last, 1, size - 1) == 1, last != 0x0A { bytes.insert(0x0A, at: 0) }
    }
    let written = bytes.withUnsafeBytes { write(descriptor, $0.baseAddress, $0.count) }
    guard written == bytes.count else {
      throw .ioFailure("short write to \(url.path): \(written) of \(bytes.count) bytes, errno \(errno)")
    }
    guard fsync(descriptor) == 0 else { throw .ioFailure("cannot flush \(url.path): errno \(errno)") }
  }
}
