// Review commands: logging the time a day took and closing its review. In their own file (SwiftLint
// file_length) rather than suppressed.
extension Commands {
  /// Sets the minutes spent on the task on `date`, replacing what that day had; none, zero or negative
  /// minutes clear them. The task may be open or completed. Setting the minutes the day has writes nothing.
  public func logTime(
    taskID: TaskID,
    on date: CalendarDate,
    minutes: Int?,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = libraryState(from: log)
    guard state.hasTask(taskID) else { throw .unknownTask(taskID) }
    let minutes = Self.positive(minutes)
    guard state.loggedMinutes(of: taskID, on: date) != minutes else { return [] }
    let event = TaskTimeLogged(taskID: taskID, date: date, minutes: minutes)
    return [envelope(EventID(ids.next()), .taskTimeLogged(event), log: log)]
  }

  /// Sets the minutes the view spent on `date` on work that was not in the plan, replacing what that day
  /// had; none, zero or negative minutes clear them. Setting the minutes the day has writes nothing.
  public func logUnplannedTime(
    _ minutes: Int?,
    for viewID: ViewID,
    on date: CalendarDate,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = libraryState(from: log)
    try requireView(viewID, in: state)
    let minutes = Self.positive(minutes)
    guard state.unplannedMinutes(in: viewID, on: date) != minutes else { return [] }
    let event = UnplannedTimeLogged(viewID: viewID, date: date, minutes: minutes)
    return [envelope(EventID(ids.next()), .unplannedTimeLogged(event), log: log)]
  }

  /// Closes the review of the view's `date` with a one-line note: line breaks and runs of spaces become one
  /// space, and a blank note is none. Reviewing a day with the note it already has writes nothing.
  public func reviewDay(
    of viewID: ViewID,
    on date: CalendarDate,
    note: String?,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = libraryState(from: log)
    try requireView(viewID, in: state)
    let note = Self.oneLine(note)
    guard !state.isReviewed(viewID, on: date) || state.reviewNote(in: viewID, on: date) != note else { return [] }
    let event = DayReviewed(viewID: viewID, date: date, note: note)
    return [envelope(EventID(ids.next()), .dayReviewed(event), log: log)]
  }

  /// The minutes if there are any; none, zero and negative minutes are none.
  private static func positive(_ minutes: Int?) -> Int? {
    minutes.flatMap { $0 > 0 ? $0 : nil }
  }

  /// The note on one line; `nil` for a blank one.
  private static func oneLine(_ note: String?) -> String? {
    guard let note else { return nil }
    let words = note.split(whereSeparator: \.isWhitespace)
    return words.isEmpty ? nil : words.joined(separator: " ")
  }
}
