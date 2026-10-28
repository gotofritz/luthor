import LuthorDomain

/// What a list can be sorted by from its header bar.
public enum ListSortKey: CaseIterable, Sendable {
  /// The order the list has: the order of a project's items, or of capture.
  case manual
  case title
  case created
  case due
  case duration
  case priority

  public var label: String {
    switch self {
    case .manual: "Manual"
    case .title: "Title"
    case .created: "Created"
    case .due: "Due"
    case .duration: "Duration"
    case .priority: "Priority"
    }
  }
}

/// What a sort looks at in an item of a list.
public struct SortFields: Equatable, Sendable {
  public let title: String
  public let created: CalendarDate?
  public let due: CalendarDate?
  public let estimate: Int?
  public let priority: Priority?

  public init(title: String, created: CalendarDate?, due: CalendarDate?, estimate: Int?, priority: Priority?) {
    self.title = title
    self.created = created
    self.due = due
    self.estimate = estimate
    self.priority = priority
  }
}

/// How a list is sorted: by one key, up or down. Only a way of showing the list; nothing is written to the log.
public struct ListSort: Equatable, Sendable {
  public var key: ListSortKey
  /// Ascending is A to Z, oldest, soonest, shortest and A first.
  public var ascending: Bool

  public static let manual = ListSort(key: .manual, ascending: true)

  public init(key: ListSortKey, ascending: Bool) {
    self.key = key
    self.ascending = ascending
  }

  /// The items in this sort; those equal keep their order, and those without the value sorted by come last
  /// whichever way it goes.
  public func sorted<Item>(_ items: [Item], by fields: (Item) -> SortFields) -> [Item] {
    guard key != .manual else { return items }
    let keyed = items.enumerated().map { (offset: $0.offset, item: $0.element, fields: fields($0.element)) }
    return keyed.sorted { lhs, rhs in
      switch compare(lhs.fields, rhs.fields) {
      case .before: true
      case .after: false
      case .same: lhs.offset < rhs.offset
      }
    }.map(\.item)
  }

  private enum Order { case before, same, after }

  private func compare(_ lhs: SortFields, _ rhs: SortFields) -> Order {
    switch key {
    case .manual: .same
    case .title: order(lhs.title.lowercased(), rhs.title.lowercased())
    case .created: order(lhs.created, rhs.created)
    case .due: order(lhs.due, rhs.due)
    case .duration: order(lhs.estimate, rhs.estimate)
    case .priority: order(Self.rank(lhs.priority), Self.rank(rhs.priority))
    }
  }

  private func order<Value: Comparable>(_ lhs: Value?, _ rhs: Value?) -> Order {
    switch (lhs, rhs) {
    case (nil, nil): return .same
    case (nil, _): return .after
    case (_, nil): return .before
    case (let left?, let right?):
      if left == right { return .same }
      return (left < right) == ascending ? .before : .after
    }
  }

  /// A first, then B, C and someday; no priority comes after C and before someday.
  private static func rank(_ priority: Priority?) -> Int {
    switch priority {
    case .critical: 0
    case .important: 1
    case .optional: 2
    case nil: 3
    case .someday: 4
    }
  }
}
