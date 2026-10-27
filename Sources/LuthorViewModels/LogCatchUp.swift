import LuthorDomain
import LuthorStore

/// What a view model holds of the log: the state, the events it was replayed from and how far the log was read,
/// the damaged lines found, and the highest Lamport counter. A value, so the log can be read into a copy away from
/// the main actor and the copy swapped in whole.
struct LogSnapshot: Sendable {
  var state = LibraryState.replay([])
  var held = HeldLog()
  var problems: [LogProblem] = []
  var lamport: UInt64 = 0
}

/// The events a view model's state was replayed from, with the cursor to read on from.
struct HeldLog: Sendable {
  var events: [EventEnvelope] = []
  var ids: Set<EventID> = []
  /// The event that sorts last in replay order: events after it can be applied on top of the state.
  var last: EventEnvelope?
  var cursor: LogCursor?

  /// Keeps `events`, once each, in place of those held before.
  init(_ events: [EventEnvelope] = [], cursor: LogCursor? = nil) {
    self.cursor = cursor
    for event in events where ids.insert(event.id).inserted { self.events.append(event) }
    last = self.events.max(by: EventEnvelope.replayOrder)
  }

  /// Adds events not held yet, and returns them.
  mutating func add(_ new: [EventEnvelope]) -> [EventEnvelope] {
    let fresh = new.filter { ids.insert($0.id).inserted }
    events += fresh
    last = (fresh + [last].compactMap { $0 }).max(by: EventEnvelope.replayOrder)
    return fresh
  }
}

/// Brings a snapshot up to the log. No state of its own and no actor, so it runs wherever it is called.
enum LogCatchUp {
  struct Result: Sendable {
    var snapshot: LogSnapshot
    /// The log's change token from before the read, so a write during it is noticed next time.
    var token: String?
    /// Whether the state differs from the one given.
    var changed: Bool
  }

  /// Reads only what was appended since the last read if the log can tell, else all of it.
  static func run(_ snapshot: LogSnapshot, log: any EventLog) throws(EventLogError) -> Result {
    var next = snapshot
    let token = log.changeToken()
    if let cursor = snapshot.held.cursor, let reading = try log.readIncrement(since: cursor) {
      next.held.cursor = reading.cursor
      for problem in reading.problems where !next.problems.contains(problem) { next.problems.append(problem) }
      let isAfterAll = reading.events.filter { !snapshot.held.ids.contains($0.id) }.min(by: EventEnvelope.replayOrder)
        .map { first in snapshot.held.last.map { EventEnvelope.replayOrder($0, first) } ?? true }
      let fresh = next.held.add(reading.events)
      guard !fresh.isEmpty else { return Result(snapshot: next, token: token, changed: false) }
      if isAfterAll == true {
        next.state.append(fresh)
      } else {
        // Another device wrote what sorts before something already applied: only a replay puts it in place.
        next.state = LibraryState.replay(next.held.events)
      }
      next.lamport = fresh.reduce(next.lamport) { max($0, $1.lamport) }
      return Result(snapshot: next, token: token, changed: true)
    }
    let reading = try log.readReportingProblems()
    next.problems = reading.problems
    next.state = LibraryState.replay(reading.events)
    next.held = HeldLog(reading.events, cursor: reading.cursor)
    next.lamport = reading.events.reduce(0) { max($0, $1.lamport) }
    return Result(snapshot: next, token: token, changed: next.state != snapshot.state)
  }
}
