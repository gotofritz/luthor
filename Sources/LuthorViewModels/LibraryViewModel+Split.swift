import LuthorDomain

/// The times of a task split in two on the day shown: the part it keeps (A) and the part cut off (B), in minutes
/// after midnight.
public struct SplitTimes: Equatable, Sendable {
  public var aStart: Int
  public var aEnd: Int
  public var bStart: Int
  public var bEnd: Int

  public init(aStart: Int, aEnd: Int, bStart: Int, bEnd: Int) {
    self.aStart = aStart
    self.aEnd = aEnd
    self.bStart = bStart
    self.bEnd = bEnd
  }
}

// Splitting a planned task in two on the day shown. In its own file (SwiftLint file_length) rather than
// suppressed.
extension LibraryViewModel {
  /// The times a split starts with. A keeps its start, and ends now when the task is under way, else where it
  /// ends. B starts now and takes what A gave up; a task not under way gives
  /// up nothing, so B is half an hour. `nil` if the task is not on the calendar.
  public func splitDefaults(of taskID: TaskID) -> SplitTimes? {
    guard let slot = planSlots.first(where: { $0.entry.task.id == taskID }) else { return nil }
    let now = minuteOfDay
    let underway = planDate == today && (slot.start..<slot.end).contains(now)
    let aEnd = underway ? now : slot.end
    let length = slot.end > aEnd ? slot.end - aEnd : 30
    let bStart = min(planDate == today ? now : aEnd, dayLimit - length)
    return SplitTimes(aStart: slot.start, aEnd: aEnd, bStart: bStart, bEnd: bStart + length)
  }

  /// Splits a planned task. A gets the times of `times`; B becomes a session of the same task. With `deferring`
  /// B is not put on the day: it is a new task, a copy of this one of the length of B, that goes back among
  /// the candidates. Nothing happens unless A ends after it starts, and B too unless it is deferred.
  public func splitTask(_ taskID: TaskID, times: SplitTimes, deferring: Bool) {
    guard times.aEnd > times.aStart, deferring || times.bEnd > times.bStart else { return }
    if deferring {
      let minutes = times.bEnd > times.bStart ? times.bEnd - times.bStart : 30
      let day = clock()
      let events = perform { (log) throws(CommandError) in
        try commands.duplicate(taskID: taskID, today: day, log: log)
      }
      for case .taskDuplicated(let duplicated) in events.map(\.payload) {
        estimate(duplicated.copy, as: minutes)
      }
    } else {
      addSession(of: taskID, start: times.bStart, end: times.bEnd)
    }
    setTimes(taskID, start: times.aStart, end: times.aEnd)
  }
}
