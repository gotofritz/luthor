import Foundation
import LuthorDomain

/// A Mac's request that every device stop writing, so the shared log can be compacted.
public struct CompactionRequest: Equatable, Codable, Sendable {
  public let id: String
  /// The file-name token of the device that asked.
  public let device: String
  public let requestedAt: String
}

/// The handshake that makes compaction safe with several Macs, done with small files in the shared folder.
/// Like the log, every file has one writer, so Dropbox never has a conflict to resolve:
///
/// 1. The asking Mac writes `compaction-<id>-request.json`, and stops writing events.
/// 2. Every other Mac that sees it writes `compaction-<id>-ack-<device>.json`, saying how many events its own
///    file holds, and stops writing events too.
/// 3. The asking Mac waits until each other device has answered *and* that many events of its file have
///    arrived, so nothing is left unsynced. It then compacts and writes `compaction-<id>-done.json`, and
///    every Mac writes again. A request can be cancelled (`-cancel.json`) the same way.
public struct CompactionHandshake: Sendable {
  /// How long a request stays open. A compaction that is not finished by then was interrupted (the app was
  /// quit, the Mac went to sleep, or it never came back), and its request must not pause the Macs for good.
  public static let lifetime: TimeInterval = 600

  public let directory: URL
  public let deviceID: DeviceID
  private let now: @Sendable () -> Date

  public init(directory: URL, deviceID: DeviceID, now: @escaping @Sendable () -> Date = { Date() }) {
    self.directory = directory
    self.deviceID = deviceID
    self.now = now
  }

  /// The device's name as it appears in file names.
  public static func token(for deviceID: DeviceID) -> String {
    let name = DeviceFilesEventLog.fileName(for: deviceID)
    return String(name.dropFirst("events-".count).dropLast(".jsonl".count))
  }

  public var token: String { Self.token(for: deviceID) }

  /// The request nobody has finished or cancelled and that has not run out; the earliest one if there are several.
  public func openRequest() throws(EventLogError) -> CompactionRequest? {
    let names = try fileNames()
    var requests: [CompactionRequest] = []
    for name in names where name.hasPrefix("compaction-") && name.hasSuffix("-request.json") {
      // The id goes into the names of the files that answer it, so only a plain one, matching its own file, counts.
      if let request = try read(CompactionRequest.self, named: name), Self.isValid(id: request.id),
        name == Self.name(request.id, "request")
      {
        requests.append(request)
      }
    }
    for request in requests.sorted(by: { $0.id < $1.id }) {
      let closed = names.contains(Self.name(request.id, "done")) || names.contains(Self.name(request.id, "cancel"))
      if !closed && !isExpired(request) { return request }
    }
    return nil
  }

  /// A request whose time cannot be read, or lies further ahead than a clock may be out, is given up at once:
  /// it cannot be told how old it is, and must not pause the Macs for good.
  private func isExpired(_ request: CompactionRequest) -> Bool {
    guard let asked = ISO8601DateFormatter().date(from: request.requestedAt) else { return true }
    return abs(now().timeIntervalSince(asked)) > Self.lifetime
  }

  /// Whether `id` is safe to put in a file name: 1 to 64 letters, digits or hyphens.
  public static func isValid(id: String) -> Bool {
    (1...64).contains(id.utf8.count) && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
  }

  /// Asks every device to stop writing; this device has stopped. Refused while a request is open.
  public func request(id: String, at time: String) throws(EventLogError) -> CompactionRequest {
    guard Self.isValid(id: id) else { throw .ioFailure("\"\(id)\" is not a valid compaction id.") }
    if try openRequest() != nil { throw .ioFailure("Another compaction is already under way.") }
    let request = CompactionRequest(id: id, device: token, requestedAt: time)
    try write(request, named: Self.name(id, "request"))
    return request
  }

  /// Says this device has stopped writing, with the number of events its file holds. Does nothing if it has
  /// said so.
  public func acknowledge(_ request: CompactionRequest, events: Int, at time: String) throws(EventLogError) {
    let name = Self.name(request.id, "ack-" + token)
    if try fileNames().contains(name) { return }
    try write(Acknowledgement(device: token, time: time, events: events), named: name)
  }

  public func hasAcknowledged(_ request: CompactionRequest) throws(EventLogError) -> Bool {
    if request.device == token { return true }
    return try fileNames().contains(Self.name(request.id, "ack-" + token))
  }

  /// The devices that have not stopped writing yet, or whose last events have not all arrived here.
  public func waitingFor(_ request: CompactionRequest) throws(EventLogError) -> [String] {
    let names = try fileNames()
    var waiting: [String] = []
    for name in names where DeviceFilesEventLog.isDeviceLog(named: name) {
      let other = String(name.dropFirst("events-".count).dropLast(".jsonl".count))
      guard other != token else { continue }
      let acknowledgement = try read(Acknowledgement.self, named: Self.name(request.id, "ack-" + other))
      if let acknowledgement, try eventCount(of: name) >= acknowledgement.events { continue }
      waiting.append(other)
    }
    return waiting.sorted()
  }

  /// Whether this device must not write events now: a request is open and it has stopped.
  public func isPaused() throws(EventLogError) -> Bool {
    try pausingRequest() != nil
  }

  /// The open request this device has stopped writing for, if any.
  public func pausingRequest() throws(EventLogError) -> CompactionRequest? {
    guard let request = try openRequest() else { return nil }
    return try hasAcknowledged(request) ? request : nil
  }

  /// Lets every device write again after the log was compacted.
  public func finish(_ request: CompactionRequest, at time: String) throws(EventLogError) {
    try write(Acknowledgement(device: token, time: time, events: 0), named: Self.name(request.id, "done"))
  }

  public func cancel(_ request: CompactionRequest) throws(EventLogError) {
    let cancelled = Acknowledgement(device: token, time: request.requestedAt, events: 0)
    try write(cancelled, named: Self.name(request.id, "cancel"))
  }

  /// The number of events in the device's own file, to put in its answer.
  public func ownEventCount() throws(EventLogError) -> Int {
    try eventCount(of: DeviceFilesEventLog.fileName(for: deviceID))
  }

  private struct Acknowledgement: Codable {
    let device: String
    let time: String
    let events: Int
  }

  private static func name(_ id: String, _ kind: String) -> String {
    "compaction-\(id)-\(kind).json"
  }

  private func fileNames() throws(EventLogError) -> [String] {
    guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
    do {
      return try FileManager.default.contentsOfDirectory(atPath: directory.path)
    } catch {
      throw .ioFailure("cannot list \(directory.path): \(error)")
    }
  }

  /// Lines that are not blank; a file that is missing holds none.
  private func eventCount(of name: String) throws(EventLogError) -> Int {
    let url = directory.appendingPathComponent(name)
    guard FileManager.default.fileExists(atPath: url.path) else { return 0 }
    do {
      let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
      return lines.reduce(0) { $0 + ($1.allSatisfy(\.isWhitespace) ? 0 : 1) }
    } catch {
      throw .ioFailure("cannot read \(url.path): \(error)")
    }
  }

  /// `nil` for a file that is missing, or half synced and not readable yet.
  private func read<Value: Decodable>(_ type: Value.Type, named name: String) throws(EventLogError) -> Value? {
    let url = directory.appendingPathComponent(name)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    guard let data = FileManager.default.contents(atPath: url.path) else { return nil }
    do {
      return try JSONDecoder().decode(Value.self, from: data)
    } catch {
      return nil
    }
  }

  private func write(_ value: some Encodable, named name: String) throws(EventLogError) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try encoder.encode(value).write(to: directory.appendingPathComponent(name), options: .atomic)
    } catch {
      throw .ioFailure("cannot write \(name): \(error)")
    }
  }
}

/// A shared-folder log that refuses to append while this device has stopped writing for a compaction.
public struct PausableEventLog: EventLog {
  private let base: any EventLog
  private let handshake: CompactionHandshake

  public init(_ base: any EventLog, handshake: CompactionHandshake) {
    self.base = base
    self.handshake = handshake
  }

  public func readAll() throws(EventLogError) -> [EventEnvelope] {
    try base.readAll()
  }

  public func readReportingProblems() throws(EventLogError) -> LogReading {
    try base.readReportingProblems()
  }

  public func quarantineUnreadableLines() throws(EventLogError) -> Int {
    try base.quarantineUnreadableLines()
  }

  public func append(_ events: [EventEnvelope]) throws(EventLogError) {
    if let request = try handshake.pausingRequest() {
      throw .ioFailure(
        "The log is being compacted by \(request.device). Try again in a moment, or cancel it in Settings → This Mac."
      )
    }
    try base.append(events)
  }
}
