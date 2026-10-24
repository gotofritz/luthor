import LuthorDomain

// Sessions: a task done on and off through the day has stretches of its own on the calendar. In its own file
// (SwiftLint file_length) rather than suppressed.
extension LibraryViewModel {
  /// Sets apart the stretch from `start` to `end` of a planned task's day as a session. The task's own block
  /// shrinks by those minutes, and what is in the way moves aside. Nothing happens unless the end is after the
  /// start.
  public func addSession(of taskID: TaskID, start: Int, end: Int) {
    guard end > start else { return }
    let day = planDate
    perform { (log) throws(CommandError) in
      try commands.setSession(of: taskID, on: day, start: start, minutes: end - start, log: log)
    }
    if let session = plan.sessions.first(where: { $0.task.id == taskID && $0.start == start }) {
      placeSession(session.id, atMinute: start)
    }
  }

  /// Changes the start and end of a session; what is in the way moves aside.
  public func setSessionTimes(_ sessionID: SessionID, start: Int, end: Int) {
    guard end > start, let session = plan.sessions.first(where: { $0.id == sessionID }) else { return }
    let day = planDate
    sessionPreview = nil
    perform { (log) throws(CommandError) in
      try commands.setSession(sessionID, of: session.task.id, on: day, start: start, minutes: end - start, log: log)
    }
    placeSession(sessionID, atMinute: start)
  }

  /// Moves a session to start at `minute`, keeping its length. It wins the place: what it overlaps moves aside
  /// and keeps the places it was given.
  public func placeSession(_ sessionID: SessionID, atMinute minute: Int) {
    guard let session = plan.sessions.first(where: { $0.id == sessionID }) else { return }
    let day = planDate
    sessionPreview = nil
    let start = min(max(minute, 0), 24 * 60 - session.minutes)
    let before = dayLayout(moving: nil, to: 0, block: nil)
    let after = dayLayout(moving: nil, to: start, block: nil, session: sessionID)
    perform { (log) throws(CommandError) in
      let placed = try commands.setSession(
        sessionID, of: session.task.id, on: day, start: start, minutes: session.minutes, log: log)
      return try placed + keepPushed(after, from: before, except: sessionID.rawValue, on: day, log: log + placed)
    }
  }

  /// Shows a session being dragged at `minute`; what is around it makes room until the drop.
  public func previewSession(_ sessionID: SessionID, atMinute minute: Int) {
    sessionPreview = (sessionID, minute)
  }

  /// Gives a session's minutes back to its task.
  public func removeSession(_ sessionID: SessionID) {
    perform { (log) throws(CommandError) in try commands.removeSession(sessionID, log: log) }
  }
}
