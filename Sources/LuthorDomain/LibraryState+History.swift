extension EventPayload {
  /// Whether the event records something a `LibraryExport` cannot hold: the plan of a day (its order,
  /// capacity, hours, start times, blocks and sessions) and the daily review (time logged, reviewed days).
  /// A compaction carries these events over instead of dropping them.
  public var isBeyondExport: Bool {
    switch self {
    case .dayPlanOrdered, .dayCapacitySet, .dayHoursSet, .taskStartSet, .dayBlockSet, .dayBlockRemoved,
      .taskSessionSet, .taskSessionRemoved, .taskTimeLogged, .unplannedTimeLogged, .dayReviewed:
      true
    default:
      false
    }
  }
}

extension LibraryState {
  /// What differs from `other` in the plan of the days and the daily review, in words, for a check that a
  /// rewritten log kept them; `nil` if both hold the same.
  public func firstDifferenceInPlanAndReview(from other: LibraryState) -> String? {
    if dayOrders != other.dayOrders { return "the plan's order differs" }
    if dayCapacities != other.dayCapacities { return "the day capacities differ" }
    if dayHours != other.dayHours { return "the day hours differ" }
    if taskStarts != other.taskStarts { return "the start times differ" }
    if dayBlocks != other.dayBlocks { return "the blocks differ" }
    if taskSessions != other.taskSessions { return "the sessions differ" }
    if reviewRecords != other.reviewRecords { return "the time logged or reviewed days differ" }
    return nil
  }
}
