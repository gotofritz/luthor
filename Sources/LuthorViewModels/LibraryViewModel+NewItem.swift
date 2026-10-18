import LuthorDomain

/// Adding an item from the plus button of a column: the item is edited on a card in the column after it, and
/// nothing is written before OK.
extension LibraryViewModel {
  /// Starts a new item in the column that lists the children of `parentID`, or the top-level projects for
  /// `nil`. The columns after that one close, so the card of the new item is the next column. Pressing the plus
  /// of the column whose item is being edited already keeps what was typed.
  public func beginNewItem(under parentID: TaskID?, kind: NewItemKind) {
    let kept = newItem
    if let parentID {
      open(.project(parentID))
    } else {
      deselectColumn(of: nil)
    }
    newItem = kept?.parentID == parentID ? kept : NewItemDraft(parentID: parentID, kind: kind)
  }

  /// Sets the title typed on the card of the new item, which the column shows as it goes.
  public func setNewItemTitle(_ title: String) {
    newItem?.card.title = title
  }

  /// Changes the new item into a task or a project of another kind.
  public func setNewItemKind(_ kind: NewItemKind) {
    newItem?.kind = kind
  }

  /// Drops the new item without writing anything.
  public func cancelNewItem() {
    newItem = nil
  }

  /// Makes the new item as the card says, in one write, and shows it: a task is selected, a project opened.
  /// A blank title writes nothing and keeps the card open.
  public func saveNewItem(_ card: TaskCardDraft) {
    guard let item = newItem, !card.title.allSatisfy(\.isWhitespace) else { return }
    let viewID = currentView
    let day = clock()
    let events = perform { (log) throws(CommandError) in
      var events = try createEvents(for: item, titled: card.title, viewID: viewID, today: day, log: log)
      guard let itemID = events.createdItemID else { return events }
      events += try cardEvents(of: itemID, card, log: log + events)
      return events
    }
    guard errorMessage == nil, let created = events.createdItemID else { return }
    newItem = nil
    switch item.kind {
    case .task:
      if tasks.contains(where: { $0.id == created }) { selection = created }
    case .project:
      open(.project(created))
    }
  }

  private func createEvents(
    for item: NewItemDraft, titled title: String, viewID: ViewID, today: CalendarDate, log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    switch item.kind {
    case .task:
      if let parentID = item.parentID {
        return try commands.capture(title: title, into: parentID, today: today, log: log)
      }
      return try commands.capture(title: title, in: viewID, today: today, log: log)
    case .project(let kind):
      if let parentID = item.parentID {
        return try commands.createProject(title: title, kind: kind, under: parentID, today: today, log: log)
      }
      return try commands.createProject(title: title, kind: kind, in: viewID, today: today, log: log)
    }
  }
}

extension [EventEnvelope] {
  /// The item the first capture among these events made.
  fileprivate var createdItemID: TaskID? {
    for case .taskCaptured(let captured) in map(\.payload) { return captured.taskID }
    return nil
  }
}
