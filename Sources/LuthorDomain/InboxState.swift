public struct TaskItem: Equatable, Sendable {
  public let id: TaskID
  public let title: String

  public init(id: TaskID, title: String) {
    self.id = id
    self.title = title
  }
}

public struct InboxState: Equatable, Sendable {
  public private(set) var openTasks: [TaskItem] = []

  /// Builds state from events in any arrival order. Duplicates (same event ID) apply once.
  public static func replay(_ events: [EventEnvelope]) -> InboxState {
    var state = InboxState()
    var seen = Set<EventID>()
    for event in events.sorted(by: EventEnvelope.replayOrder) where seen.insert(event.id).inserted {
      state.apply(event.payload)
    }
    return state
  }

  mutating func apply(_ payload: EventPayload) {
    switch payload {
    case .taskCaptured(let captured):
      openTasks.append(TaskItem(id: captured.taskID, title: captured.title))
    case .taskCompleted(let completed):
      openTasks.removeAll { $0.id == completed.taskID }
    }
  }
}
