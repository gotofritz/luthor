/// Puts a block of untracked time on one view's day, or changes the one with this ID: a lunch, a shopping
/// trip. Times are minutes after midnight. Tasks flow round it, and it is not counted in the capacity.
public struct DayBlockSet: Equatable, Codable, Sendable {
  public let blockID: BlockID
  public let viewID: ViewID
  public let date: CalendarDate
  public let title: String
  public let start: Int
  public let end: Int

  public init(blockID: BlockID, viewID: ViewID, date: CalendarDate, title: String, start: Int, end: Int) {
    self.blockID = blockID
    self.viewID = viewID
    self.date = date
    self.title = title
    self.start = start
    self.end = end
  }
}

/// Takes a block of untracked time off its day.
public struct DayBlockRemoved: Equatable, Codable, Sendable {
  public let blockID: BlockID

  public init(blockID: BlockID) {
    self.blockID = blockID
  }
}
