// Giving a new item the priority and estimate its place gives it. In its own file (SwiftLint type_body_length)
// rather than suppressed.
extension Commands {
  /// The events that give the open item `taskID` the priority and estimate in `defaults`, those it has none of.
  func defaultEvents(of taskID: TaskID, _ defaults: ItemDefaults, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    var events: [EventEnvelope] = []
    if let priority = defaults.priority {
      events += try prioritize(taskID: taskID, as: priority, log: log)
    }
    if let minutes = defaults.estimate {
      events += try estimate(taskID: taskID, as: minutes, log: log + events)
    }
    return events
  }
}
