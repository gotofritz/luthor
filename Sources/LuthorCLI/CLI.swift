import Foundation
import LuthorDomain
import LuthorStore

public struct CLIResult: Equatable, Sendable {
  public var exitCode: Int32
  public var output: String
  public var error: String

  public init(exitCode: Int32, output: String = "", error: String = "") {
    self.exitCode = exitCode
    self.output = output
    self.error = error
  }
}

/// The `luthor` command line: `add`, `list`, `done`. Pure apart from the log file it is pointed at.
public struct CLI {
  static let usage = """
    usage: luthor add <title>      capture a task into the inbox
           luthor list             show open tasks
           luthor done <id-prefix> complete the open task whose ID starts with <id-prefix>

    environment:
      LUTHOR_LOG        path of the event log (default: ~/.luthor/events.jsonl)
      LUTHOR_DEVICE_ID  name of this device in the log (default: local)

    """

  private static let exitFailure: Int32 = 1
  /// `EX_USAGE` from sysexits.h.
  private static let exitUsage: Int32 = 64

  private let configuration: LuthorConfiguration
  private let ids: any IDGenerator

  public init(environment: [String: String], home: URL, ids: any IDGenerator) {
    configuration = LuthorConfiguration(environment: environment, home: home)
    self.ids = ids
  }

  public func run(_ arguments: [String]) -> CLIResult {
    guard let command = arguments.first else { return CLIResult(exitCode: Self.exitUsage, error: Self.usage) }
    let rest = Array(arguments.dropFirst())
    let action: (Session) throws -> CLIResult
    switch command {
    case "help", "--help", "-h":
      return CLIResult(exitCode: 0, output: Self.usage)
    case "add":
      action = { try add(title: rest.joined(separator: " "), $0) }
    case "list" where rest.isEmpty:
      action = { list($0) }
    case "done" where rest.count == 1:
      action = { try done(idPrefix: rest[0], $0) }
    default:
      return CLIResult(exitCode: Self.exitUsage, error: Self.usage)
    }
    let path = configuration.logURL.path
    let session: Session
    do {
      session = try Session(path: path, deviceID: configuration.deviceID, ids: ids)
    } catch {
      return report(error, path: path)
    }
    return perform(action, session, path: path)
  }

  private func perform(_ action: (Session) throws -> CLIResult, _ session: Session, path: String) -> CLIResult {
    do {
      return try action(session)
    } catch let error as CommandError {
      return report(error, open: session.open)
    } catch let error as EventLogError {
      return report(error, path: path)
    } catch {
      return failure(Self.exitFailure, "\(error)")
    }
  }

  /// The log as read at the start of one command.
  private struct Session {
    let store: JSONLinesEventLog
    let commands: Commands
    let log: [EventEnvelope]
    let open: [TaskItem]

    init(path: String, deviceID: DeviceID, ids: any IDGenerator) throws(EventLogError) {
      store = JSONLinesEventLog(fileURL: URL(fileURLWithPath: path))
      commands = Commands(deviceID: deviceID, ids: ids)
      log = try store.readAll()
      open = LibraryState.replay(log).openTasks
    }
  }

  private func add(title: String, _ session: Session) throws -> CLIResult {
    let events = try session.commands.capture(title: title, log: session.log)
    try session.store.append(events)
    let captured = events.compactMap(Self.capturedTask)
    return CLIResult(exitCode: 0, output: captured.map { "Captured " + Self.line($0) }.joined())
  }

  private func list(_ session: Session) -> CLIResult {
    CLIResult(exitCode: 0, output: session.open.map(Self.line).joined())
  }

  private func done(idPrefix: String, _ session: Session) throws -> CLIResult {
    let events = try session.commands.complete(idPrefix: idPrefix, log: session.log)
    try session.store.append(events)
    let done = events.compactMap(Self.completedTaskID).compactMap { id in session.open.first { $0.id == id } }
    return CLIResult(exitCode: 0, output: done.map { "Completed " + Self.line($0) }.joined())
  }

  private static func capturedTask(_ event: EventEnvelope) -> TaskItem? {
    guard case .taskCaptured(let captured) = event.payload else { return nil }
    return TaskItem(id: captured.taskID, title: captured.title)
  }

  private static func completedTaskID(_ event: EventEnvelope) -> TaskID? {
    guard case .taskCompleted(let completed) = event.payload else { return nil }
    return completed.taskID
  }

  private func report(_ error: CommandError, open: [TaskItem]) -> CLIResult {
    switch error {
    case .blankTitle:
      return failure(Self.exitUsage, "a task needs a title")
    case .noOpenTask(let prefix):
      return failure(Self.exitFailure, "no open task matches '\(prefix)'")
    case .ambiguousPrefix(let prefix, let matches):
      let candidates = matches.compactMap { id in open.first { $0.id == id } }.map(Self.line).joined()
      return failure(Self.exitFailure, "'\(prefix)' matches more than one open task:\n" + candidates.dropLast())
    case .noActiveProject(let projectID):
      return failure(Self.exitFailure, "no active project '\(projectID.rawValue)'")
    }
  }

  private func report(_ error: EventLogError, path: String) -> CLIResult {
    switch error {
    case .unreadableLine(let number):
      failure(Self.exitFailure, "\(path) line \(number) is not a readable event")
    case .ioFailure(let message):
      failure(Self.exitFailure, message)
    }
  }

  private func failure(_ code: Int32, _ message: String) -> CLIResult {
    CLIResult(exitCode: code, error: "luthor: \(message)\n")
  }

  private static func line(_ task: TaskItem) -> String {
    "\(task.id.rawValue.prefix(8))  \(task.title)\n"
  }
}
