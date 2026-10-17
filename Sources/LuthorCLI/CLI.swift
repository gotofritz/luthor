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

/// The `luthor` command line: `add`, `list`, `done`, each in one view. Pure apart from the log file it
/// is pointed at.
public struct CLI {
  static let usage = """
    usage: luthor add [--view <name>] <title>       capture a task into the view's inbox
           luthor list [--view <name>]              show the view's open tasks
           luthor done [--view <name>] <id-prefix>  complete the view's open task whose ID starts with <id-prefix>

    <title> may carry !a, !b, !c or !someday for a priority and <n>m for an estimate in minutes, e.g.
    "call bank !a 15m"; both are stripped from the title.

    environment:
      LUTHOR_LOG        path of the event log (default: ~/.luthor/events.jsonl)
      LUTHOR_DEVICE_ID  name of this device in the log (default: local)
      LUTHOR_VIEW       name of the view to use without --view (default: the default view)

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
    guard let command = arguments.first, let (viewName, rest) = Self.viewOption(Array(arguments.dropFirst()))
    else { return CLIResult(exitCode: Self.exitUsage, error: Self.usage) }
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
    let name = viewName ?? configuration.viewName
    guard let view = session.view(named: name) else {
      return failure(Self.exitFailure, "no view named '\(name ?? "")'")
    }
    return perform(action, session.in(view), path: path)
  }

  /// Splits a leading `--view <name>` off the arguments; `nil` if the name is missing.
  private static func viewOption(_ arguments: [String]) -> (name: String?, rest: [String])? {
    guard arguments.first == "--view" else { return (nil, arguments) }
    guard arguments.count > 1 else { return nil }
    return (arguments[1], Array(arguments.dropFirst(2)))
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

  /// The log as read at the start of one command, and the one view the command works in.
  private struct Session {
    let store: JSONLinesEventLog
    let commands: Commands
    let log: [EventEnvelope]
    let state: LibraryState
    private(set) var viewID = ViewID.default

    init(path: String, deviceID: DeviceID, ids: any IDGenerator) throws(EventLogError) {
      store = JSONLinesEventLog(fileURL: URL(fileURLWithPath: path))
      commands = Commands(deviceID: deviceID, ids: ids)
      log = try store.readAll()
      state = LibraryState.replay(log)
    }

    /// The open tasks of the session's view.
    var open: [TaskItem] { state.view(viewID).openTasks }

    /// The view with this name, ignoring case; the default view for `nil`.
    func view(named name: String?) -> ViewID? {
      guard let name else { return .default }
      return state.view(named: name)?.id
    }

    func `in`(_ viewID: ViewID) -> Session {
      var session = self
      session.viewID = viewID
      return session
    }
  }

  private func add(title: String, _ session: Session) throws -> CLIResult {
    let events = try session.commands.capture(title: title, in: session.viewID, log: session.log)
    try session.store.append(events)
    let captured = events.compactMap(Self.capturedTask)
    return CLIResult(exitCode: 0, output: captured.map { "Captured " + Self.line($0) }.joined())
  }

  private func list(_ session: Session) -> CLIResult {
    CLIResult(exitCode: 0, output: session.open.map(Self.line).joined())
  }

  private func done(idPrefix: String, _ session: Session) throws -> CLIResult {
    let events = try session.commands.complete(idPrefix: idPrefix, in: session.viewID, log: session.log)
    try session.store.append(events)
    let done = events.compactMap(Self.completedTaskID).compactMap { id in session.open.first { $0.id == id } }
    return CLIResult(exitCode: 0, output: done.map { "Completed " + Self.line($0) }.joined())
  }

  private static func capturedTask(_ event: EventEnvelope) -> TaskItem? {
    guard case .taskCaptured(let captured) = event.payload else { return nil }
    return TaskItem(id: captured.taskID, title: captured.title, viewID: captured.viewID)
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
    case .noActiveProject, .noView, .duplicateViewName, .otherView, .projectInOtherView, .nestedUnderItself:
      // Only the app files tasks, nests projects and manages views; the commands the CLI runs never throw these.
      return failure(Self.exitFailure, "\(error)")
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
