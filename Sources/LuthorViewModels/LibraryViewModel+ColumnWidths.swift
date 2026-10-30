import LuthorDomain

/// The width of each column of a list, dragged from its header. Each place keeps its own, and the app keeps them
/// per device through `onColumnWidthsChanged`; like a sort, it is only a way of showing the list and writes
/// nothing to the log.
extension LibraryViewModel {
  /// The least and most a column can be dragged to.
  public static let columnWidthRange: ClosedRange<Double> = 16...400

  /// How wide the column is in the place the list is in.
  public func columnWidth(_ column: ListColumn, inList listID: String) -> Double {
    columnWidths[place(ofList: listID)]?[column.rawValue] ?? column.defaultWidth
  }

  /// Sets the width of the column for the place the list is in, held within `columnWidthRange`.
  public func setColumnWidth(_ width: Double, of column: ListColumn, inList listID: String) {
    let clamped = min(max(width, Self.columnWidthRange.lowerBound), Self.columnWidthRange.upperBound)
    columnWidths[place(ofList: listID), default: [:]][column.rawValue] = clamped
    onColumnWidthsChanged?(columnWidths)
  }

  /// The widest text the rows of the column show, for the app to measure when it fits the column to its content;
  /// `nil` when the column shows no text, as the priority symbols, or no row has any.
  public func widestText(in column: ListColumn, inList listID: String) -> String? {
    let texts: [String]
    switch column {
    case .duration: texts = listedTasks.compactMap { $0.estimate.map { "\($0)m" } }
    case .when: texts = listedTasks.compactMap { listedDate(of: $0.id)?.isoString }
    case .status, .priority: texts = []
    }
    return texts.max { $0.count < $1.count }
  }

  /// The tasks any list of the place shows: those listed and those in the columns of the project browser.
  private var listedTasks: [TaskItem] {
    tasks
      + columns.flatMap(\.entries).compactMap { entry -> TaskItem? in
        if case .task(let task) = entry { task } else { nil }
      }
  }
}
