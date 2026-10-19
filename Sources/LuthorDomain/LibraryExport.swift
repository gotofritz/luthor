/// The tasks and projects of a library as plain data, for a text copy that does not depend on the event log:
/// what exists and where it stands, not how it got there. History (time logged, reviews, the plan's manual
/// order, settings) is not part of it.
public struct LibraryExport: Equatable, Codable, Sendable {
  public static let formatVersion = 1

  public var format: Int
  public var views: [ExportedView]
  public var tags: [ExportedTag]
  /// Parents come before their children, children in the order of their project; roots in capture order.
  public var items: [ExportedItem]

  public init(
    format: Int = LibraryExport.formatVersion, views: [ExportedView], tags: [ExportedTag], items: [ExportedItem]
  ) {
    self.format = format
    self.views = views
    self.tags = tags
    self.items = items
  }
}

public struct ExportedView: Equatable, Codable, Sendable {
  public var id: ViewID
  public var name: String

  public init(id: ViewID, name: String) {
    self.id = id
    self.name = name
  }
}

public struct ExportedTag: Equatable, Codable, Sendable {
  public var id: TagID
  public var name: String
  public var view: ViewID

  public init(id: TagID, name: String, view: ViewID) {
    self.id = id
    self.name = name
    self.view = view
  }
}

/// A task or project. A field that is not set is left out of the text.
public struct ExportedItem: Equatable, Codable, Sendable {
  public enum Status: String, Codable, Sendable {
    case open, completed, dropped
  }

  public struct Due: Equatable, Codable, Sendable {
    public var date: CalendarDate
    public var hard: Bool

    public init(date: CalendarDate, hard: Bool) {
      self.date = date
      self.hard = hard
    }
  }

  public struct Delegated: Equatable, Codable, Sendable {
    public var to: String
    public var since: CalendarDate
    public var followUp: CalendarDate?

    public init(to: String, since: CalendarDate, followUp: CalendarDate? = nil) {
      self.to = to
      self.since = since
      self.followUp = followUp
    }
  }

  public var id: TaskID
  public var title: String
  public var view: ViewID
  public var parent: TaskID?
  /// `parallel` or `sequential` for a project; left out for a task.
  public var kind: ProjectKind?
  public var notes: String?
  public var priority: Priority?
  public var estimate: Int?
  public var createdOn: CalendarDate?
  public var status: Status
  /// The project whose completion or drop took this item along.
  public var finishedWith: TaskID?
  public var scheduled: CalendarDate?
  public var due: Due?
  public var repeatRule: RepeatRule?
  public var delegated: Delegated?
  public var tags: [TagID]?

  public init(
    id: TaskID, title: String, view: ViewID, parent: TaskID? = nil, kind: ProjectKind? = nil,
    notes: String? = nil, priority: Priority? = nil, estimate: Int? = nil, createdOn: CalendarDate? = nil,
    status: Status = .open, finishedWith: TaskID? = nil, scheduled: CalendarDate? = nil, due: Due? = nil,
    repeatRule: RepeatRule? = nil, delegated: Delegated? = nil, tags: [TagID]? = nil
  ) {
    self.id = id
    self.title = title
    self.view = view
    self.parent = parent
    self.kind = kind
    self.notes = notes
    self.priority = priority
    self.estimate = estimate
    self.createdOn = createdOn
    self.status = status
    self.finishedWith = finishedWith
    self.scheduled = scheduled
    self.due = due
    self.repeatRule = repeatRule
    self.delegated = delegated
    self.tags = tags
  }
}

extension LibraryState {
  /// Every view, tag and item, open, completed and dropped.
  public func export() -> LibraryExport {
    LibraryExport(
      views: views.map { ExportedView(id: $0.id, name: $0.name) },
      tags: tagItems.map { ExportedTag(id: $0.id, name: $0.name, view: $0.viewID) },
      items: exportOrder().compactMap(exportedItem))
  }

  /// Roots in capture order, each followed by its descendants: first the items filed in it, in their order,
  /// then those finished on their own. An item whose parent no longer exists comes last, as a root.
  private func exportOrder() -> [TaskID] {
    var result: [TaskID] = []
    var seen = Set<TaskID>()
    func visit(_ id: TaskID) {
      guard seen.insert(id).inserted else { return }
      result.append(id)
      let filedHere = (filed[id] ?? []).filter { items[$0]?.item.parentID == id }
      let rest = order.filter { items[$0]?.item.parentID == id && !filedHere.contains($0) }
      for child in filedHere + rest { visit(child) }
    }
    for id in order where items[id]?.item.parentID == nil { visit(id) }
    for id in order { visit(id) }
    return result
  }

  private func exportedItem(_ id: TaskID) -> ExportedItem? {
    guard let stored = items[id] else { return nil }
    let item = stored.item
    var exported = ExportedItem(
      id: id, title: item.title, view: item.viewID, parent: item.parentID, kind: item.kind, notes: item.notes,
      priority: item.priority, estimate: item.estimate, createdOn: item.createdOn)
    switch stored.status {
    case .open: break
    case .completed(let with):
      exported.status = .completed
      exported.finishedWith = with
    case .dropped(let with):
      exported.status = .dropped
      exported.finishedWith = with
    }
    exported.scheduled = scheduledDates[id]
    exported.due = dueDates[id].map { ExportedItem.Due(date: $0.date, hard: $0.isHard) }
    exported.repeatRule = repeatRules[id]
    exported.delegated = delegations[id].map {
      ExportedItem.Delegated(to: $0.person, since: $0.since, followUp: $0.followUpDate)
    }
    if let tagIDs = taskTags[id], !tagIDs.isEmpty {
      exported.tags = tagItems.map(\.id).filter { tagIDs.contains($0) }
    }
    return exported
  }
}
