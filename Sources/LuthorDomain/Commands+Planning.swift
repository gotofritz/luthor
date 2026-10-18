// Planning commands: scheduling, ordering, capacity, delegating and deciding. In their own file
// (SwiftLint file_length) rather than suppressed.
extension Commands {
  /// Plans the open task `taskID` for `date`, moving it if it was planned for another day. Planning it for
  /// the day it has writes nothing. A delegated task is reclaimed first: planning it takes it back.
  public func schedule(taskID: TaskID, on date: CalendarDate, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let state = LibraryState.replay(log)
    guard let task = state.openTasks.first(where: { $0.id == taskID }) else { throw .noOpenTask(taskID.rawValue) }
    guard task.priority != .someday else { throw .someday(taskID) }
    guard state.scheduledDate(of: taskID) != date else { return [] }
    var events: [EventEnvelope] = []
    if state.delegation(of: taskID) != nil {
      events = [envelope(EventID(ids.next()), .taskReclaimed(TaskReclaimed(taskID: taskID)), log: log)]
    }
    events.append(
      envelope(EventID(ids.next()), .taskScheduled(TaskScheduled(taskID: taskID, date: date)), log: log + events))
    return events
  }

  /// Takes the open task `taskID` off its day. A task planned for no day writes nothing.
  public func unschedule(taskID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    guard state.openTasks.contains(where: { $0.id == taskID }) else { throw .noOpenTask(taskID.rawValue) }
    guard state.scheduledDate(of: taskID) != nil else { return [] }
    return [envelope(EventID(ids.next()), .taskUnscheduled(TaskUnscheduled(taskID: taskID)), log: log)]
  }

  /// Sets the order of the view's plan for `date`. Every task must be open in the view. Setting the order
  /// the plan already has writes nothing.
  public func orderPlan(
    of viewID: ViewID,
    on date: CalendarDate,
    as taskIDs: [TaskID],
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    try requireView(viewID, in: state)
    let open = Set(state.view(viewID).openTasks.map(\.id))
    if let missing = taskIDs.first(where: { !open.contains($0) }) { throw .noOpenTask(missing.rawValue) }
    var seen = Set<TaskID>()
    let ordered = taskIDs.filter { seen.insert($0).inserted }
    guard state.manualOrder(in: viewID, on: date) != ordered else { return [] }
    let event = DayPlanOrdered(viewID: viewID, date: date, taskIDs: ordered)
    return [envelope(EventID(ids.next()), .dayPlanOrdered(event), log: log)]
  }

  /// Sets the minutes the view has on `date` in place of its weekday's capacity, or with `nil` clears
  /// them. Setting the capacity the day has writes nothing.
  public func setCapacity(
    _ minutes: Int?,
    for viewID: ViewID,
    on date: CalendarDate,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    try requireView(viewID, in: state)
    guard state.capacityOverride(in: viewID, on: date) != minutes else { return [] }
    let event = DayCapacitySet(viewID: viewID, date: date, minutes: minutes)
    return [envelope(EventID(ids.next()), .dayCapacitySet(event), log: log)]
  }

  /// Hands the open task `taskID` to `name` on the day `since`, to come back on `followUp` if there is one.
  /// Handing it over on the same terms again writes nothing.
  public func delegate(
    taskID: TaskID,
    to name: String,
    since: CalendarDate,
    followUp: CalendarDate?,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    let name = try Self.named(name)
    let state = LibraryState.replay(log)
    guard state.openTasks.contains(where: { $0.id == taskID }) else { throw .noOpenTask(taskID.rawValue) }
    let delegation = Delegation(to: name, since: since, followUpDate: followUp)
    guard state.delegation(of: taskID) != delegation else { return [] }
    let event = TaskDelegated(taskID: taskID, to: name, since: since, followUpDate: followUp)
    return [envelope(EventID(ids.next()), .taskDelegated(event), log: log)]
  }

  /// Takes the delegated task `taskID` back. A task that is not delegated writes nothing.
  public func reclaim(taskID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    let state = LibraryState.replay(log)
    guard state.openTasks.contains(where: { $0.id == taskID }) else { throw .noOpenTask(taskID.rawValue) }
    guard state.delegation(of: taskID) != nil else { return [] }
    return [envelope(EventID(ids.next()), .taskReclaimed(TaskReclaimed(taskID: taskID)), log: log)]
  }

  /// Gives up the open task `taskID`: it leaves every list without being completed.
  public func drop(taskID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    guard LibraryState.replay(log).openTasks.contains(where: { $0.id == taskID }) else {
      throw .noOpenTask(taskID.rawValue)
    }
    return [envelope(EventID(ids.next()), .taskDropped(TaskDropped(taskID: taskID)), log: log)]
  }

  /// Takes the open task `taskID` off its day and gives it the someday priority. A task that repeats stops: a
  /// task not committed to has no next one.
  public func sendToSomeday(taskID: TaskID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    var events = try unschedule(taskID: taskID, log: log)
    events += try prioritize(taskID: taskID, as: .someday, log: log + events)
    if LibraryState.replay(log).repeatRule(of: taskID) != nil {
      let stopped = TaskRepeatSet(taskID: taskID, rule: nil)
      events.append(envelope(EventID(ids.next()), .taskRepeatSet(stopped), log: log + events))
    }
    return events
  }
}
