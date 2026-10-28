import LuthorDomain

// Undo and redo of the commands run in this session. Each appends new events that put back what the command
// changed (or write it again); nothing written to the log is ever edited or removed.
extension LibraryViewModel {
  public var canUndo: Bool { !undoSteps.isEmpty }
  public var canRedo: Bool { !redoSteps.isEmpty }

  /// Takes back the last command run here that can be taken back. Does nothing when there is none.
  public func undo() {
    guard let step = undoSteps.last else { return }
    let written = perform(recordsUndo: false) { (log) throws(CommandError) in
      commands.append(step.backward, log: log)
    }
    guard !written.isEmpty else { return }
    undoSteps.removeLast()
    redoSteps.append(step)
  }

  /// Does again the command last undone, unless a new command was run since. Does nothing when there is none.
  public func redo() {
    guard let step = redoSteps.last else { return }
    let written = perform(recordsUndo: false) { (log) throws(CommandError) in
      commands.append(step.forward, log: log)
    }
    guard !written.isEmpty else { return }
    redoSteps.removeLast()
    undoSteps.append(step)
  }
}
