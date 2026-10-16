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
      LUTHOR_LOG        path of the event log (required)
      LUTHOR_DEVICE_ID  name of this device in the log (default: local)

    """

  private static let exitFailure: Int32 = 1
  /// `EX_USAGE` from sysexits.h.
  private static let exitUsage: Int32 = 64
  /// `EX_CONFIG` from sysexits.h.
  private static let exitConfig: Int32 = 78

  private let environment: [String: String]
  private let ids: any IDGenerator

  public init(environment: [String: String], ids: any IDGenerator) {
    self.environment = environment
    self.ids = ids
  }

  public func run(_ arguments: [String]) -> CLIResult {
    guard let command = arguments.first else { return CLIResult(exitCode: Self.exitUsage, error: Self.usage) }
    let rest = Array(arguments.dropFirst())
    if ["help", "--help", "-h"].contains(command) { return CLIResult(exitCode: 0, output: Self.usage) }
    guard ["add", "list", "done"].contains(command) else {
      return CLIResult(exitCode: Self.exitUsage, error: Self.usage)
    }
    guard let path = environment["LUTHOR_LOG"], !path.isEmpty else {
      return failure(Self.exitConfig, "set LUTHOR_LOG to the path of the event log")
    }
    let store = JSONLinesEventLog(fileURL: URL(fileURLWithPath: path))
    let commands = Commands(deviceID: DeviceID(environment["LUTHOR_DEVICE_ID"] ?? "local"), ids: ids)

    let log: [EventEnvelope]
    do {
      log = try store.readAll()
    } catch {
      return report(error, path: path)
    }
    let open = InboxState.replay(log).openTasks

    do {
      switch command {
      case "add":
        let events = try commands.capture(title: rest.joined(separator: " "), log: log)
        try store.append(events)
        return CLIResult(exitCode: 0, output: events.compactMap(Self.capturedTask).map { "Captured " + Self.line($0) }.joined())
      case "done":
        guard rest.count == 1 else { return CLIResult(exitCode: Self.exitUsage, error: Self.usage) }
        let events = try commands.complete(idPrefix: rest[0], log: log)
        try store.append(events)
        let done = events.compactMap(Self.completedTaskID).compactMap { id in open.first { $0.id == id } }
        return CLIResult(exitCode: 0, output: done.map { "Completed " + Self.line($0) }.joined())
      default:
        return CLIResult(exitCode: 0, output: open.map(Self.line).joined())
      }
    } catch let error as CommandError {
      return report(error, open: open)
    } catch let error as EventLogError {
      return report(error, path: path)
    } catch {
      return failure(Self.exitFailure, "\(error)")
    }
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
    }
  }

  private func report(_ error: EventLogError, path: String) -> CLIResult {
    switch error {
    case .unreadableLine(let number):
      failure(Self.exitFailure, "\(path) line \(number) is not a readable event")
    case .io(let message):
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
