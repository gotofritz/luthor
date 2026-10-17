import LuthorDomain
import LuthorStore
import Observation

/// The inbox window: open tasks, the capture field and the keyboard selection.
///
/// Every action re-reads the log first, so events another process appended (the CLI) are never missed
/// and new events follow the highest Lamport counter on disk.
@MainActor
@Observable
public final class InboxViewModel {
  public private(set) var tasks: [TaskItem] = []
  public var draft = ""
  public var selection: TaskID?
  public private(set) var errorMessage: String?

  private let log: any EventLog
  private let commands: Commands

  public init(log: any EventLog, commands: Commands) {
    self.log = log
    self.commands = commands
  }

  public func reload() {
    do {
      show(try log.readAll())
    } catch {
      errorMessage = Self.describe(error)
    }
  }

  /// Captures the draft as a new task. A blank draft captures nothing; a failed write keeps the draft.
  public func submit() {
    let title = draft
    perform { (log) throws(CommandError) in try commands.capture(title: title, log: log) }
    if errorMessage == nil { draft = "" }
  }

  public func complete(_ taskID: TaskID) {
    perform { (log) throws(CommandError) in try commands.complete(taskID: taskID, log: log) }
  }

  /// Moves the selection up (negative) or down (positive), stopping at the ends. With nothing selected,
  /// down selects the first task and up the last.
  public func moveSelection(by offset: Int) {
    guard let current = selection.flatMap(index(of:)) else {
      selection = (offset < 0 ? tasks.last : tasks.first)?.id
      return
    }
    selection = tasks[min(max(current + offset, 0), tasks.count - 1)].id
  }

  /// Completes the selected task and selects the one that takes its place in the list.
  public func completeSelected() {
    guard let selected = selection, let position = index(of: selected) else { return }
    complete(selected)
    guard !tasks.contains(where: { $0.id == selected }) else { return }
    selection = tasks.isEmpty ? nil : tasks[min(position, tasks.count - 1)].id
  }

  private func perform(_ command: ([EventEnvelope]) throws(CommandError) -> [EventEnvelope]) {
    let current: [EventEnvelope]
    do {
      current = try log.readAll()
    } catch {
      errorMessage = Self.describe(error)
      return
    }
    let events: [EventEnvelope]
    do {
      events = try command(current)
    } catch {
      // A blank title, or a task completed elsewhere since the last reload: nothing to write, and
      // nothing the user needs to fix.
      show(current)
      return
    }
    do {
      try log.append(events)
    } catch {
      errorMessage = Self.describe(error)
      return
    }
    show(current + events)
  }

  private func show(_ events: [EventEnvelope]) {
    tasks = InboxState.replay(events).openTasks
    if let selected = selection, index(of: selected) == nil { selection = nil }
    errorMessage = nil
  }

  private func index(of taskID: TaskID) -> Int? {
    tasks.firstIndex { $0.id == taskID }
  }

  private static func describe(_ error: EventLogError) -> String {
    switch error {
    case .unreadableLine(let number): "Line \(number) of the event log is not a readable event."
    case .ioFailure(let message): message
    }
  }
}
