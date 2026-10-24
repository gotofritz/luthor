extension Commands {
  /// Puts a block of untracked time, such as lunch, on the view's day. A blank title becomes "Break"; hours that
  /// do not fit in a day are refused.
  public func addBlock(
    title: String,
    hours: DayHours,
    for viewID: ViewID,
    on date: CalendarDate,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    try requireView(viewID, in: LibraryState.replay(log))
    guard hours.isValid else { throw .invalidHours }
    let event = DayBlockSet(
      blockID: BlockID(ids.next()), viewID: viewID, date: date, title: Self.blockTitle(title), start: hours.start,
      end: hours.end)
    return [envelope(EventID(ids.next()), .dayBlockSet(event), log: log)]
  }

  /// Changes a block's title and times; it stays on its view and day. Changing nothing writes nothing.
  public func updateBlock(
    _ blockID: BlockID,
    title: String,
    start: Int,
    end: Int,
    log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    guard let placed = LibraryState.replay(log).dayBlocks[blockID] else { throw .noBlock(blockID) }
    guard DayHours(start: start, end: end).isValid else { throw .invalidHours }
    let title = Self.blockTitle(title)
    let block = placed.block
    guard block.title != title || block.start != start || block.end != end else { return [] }
    let event = DayBlockSet(
      blockID: blockID, viewID: placed.viewID, date: placed.date, title: title, start: start, end: end)
    return [envelope(EventID(ids.next()), .dayBlockSet(event), log: log)]
  }

  /// Takes a block off its day.
  public func removeBlock(_ blockID: BlockID, log: [EventEnvelope]) throws(CommandError) -> [EventEnvelope] {
    guard LibraryState.replay(log).dayBlocks[blockID] != nil else { throw .noBlock(blockID) }
    return [envelope(EventID(ids.next()), .dayBlockRemoved(DayBlockRemoved(blockID: blockID)), log: log)]
  }

  private static func blockTitle(_ title: String) -> String {
    let title = trimmed(title)
    return title.isEmpty ? "Break" : title
  }
}
