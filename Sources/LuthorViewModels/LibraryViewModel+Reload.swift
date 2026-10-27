import LuthorDomain
import LuthorStore

// Reading the log into the state held, on the main actor or away from it. Split from the Presenting file (SwiftLint
// file_length).
extension LibraryViewModel {
  public func reload() {
    do {
      guard !isUpToDateWithLog() else { return }
      let problems = logProblems
      let changed = try readLog()
      show(ifChanged: changed, problemsBefore: problems)
    } catch {
      errorMessage = Self.describe(error)
    }
  }

  /// Like `reload`, but reads the log, decodes and replays away from the main actor, which only swaps in the
  /// result; typing and scrolling go on meanwhile. An action taken while it reads makes its result stale, and
  /// the log is then read again from what the action left.
  public func reloadInBackground() async {
    for _ in 0..<3 {
      guard !isUpToDateWithLog() else { return }
      let (before, log, started) = (snapshot, log, generation)
      let outcome = await Task.detached { () -> Swift.Result<LogCatchUp.Result, EventLogError> in
        do throws(EventLogError) {
          return .success(try LogCatchUp.run(before, log: log))
        } catch {
          return .failure(error)
        }
      }.value
      guard started == generation else { continue }
      switch outcome {
      case .success(let result):
        adopt(result)
        show(ifChanged: result.changed, problemsBefore: before.problems)
      case .failure(let error):
        errorMessage = Self.describe(error)
      }
      return
    }
    reload()
  }

  /// Whether the log has not changed since it was read and nothing shown depends on the clock: nothing to read.
  private func isUpToDateWithLog() -> Bool {
    guard revision > 0, let token = log.changeToken(), token == loggedToken, clock() == today else { return false }
    if errorMessage != nil { errorMessage = nil }
    return true
  }

  /// Presents the state read, unless nothing shown changed: a sync client that only touched the file, or the app's
  /// own write seen again.
  private func show(ifChanged changed: Bool, problemsBefore problems: [LogProblem]) {
    if revision > 0, !changed, problems == logProblems, clock() == today {
      if errorMessage != nil { errorMessage = nil }
      return
    }
    showState()
  }

  /// What is held of the log, as a value.
  var snapshot: LogSnapshot {
    LogSnapshot(state: state, held: held, problems: logProblems, lamport: lastLamport)
  }

  /// Takes up a snapshot made from `snapshot` and brought up to the log.
  func adopt(_ result: LogCatchUp.Result) {
    state = result.snapshot.state
    held = result.snapshot.held
    logProblems = result.snapshot.problems
    lastLamport = result.snapshot.lamport
    loggedToken = result.token
    generation += 1
  }

  /// Brings `state` up to the log, reading only what was appended since the last read if the log can tell. `true`
  /// if that changed `state`.
  func readLog() throws(EventLogError) -> Bool {
    let result = try LogCatchUp.run(snapshot, log: log)
    adopt(result)
    return result.changed
  }
}
