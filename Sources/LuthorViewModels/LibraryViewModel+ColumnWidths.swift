import LuthorDomain

/// The width of each column of the browser, dragged from the grip at the foot of its edge. Each column keeps its own,
/// and the app keeps them per device through `onColumnWidthsChanged`; like a sort, it is only a way of showing the
/// list and writes nothing to the log.
extension LibraryViewModel {
  /// The least and most a column can be dragged to.
  public static let columnWidthRange: ClosedRange<Double> = 120...900

  /// The width of the column, or `usually` while it has not been resized.
  public func columnWidth(of columnID: String, usually: Double) -> Double {
    columnWidths[columnID] ?? usually
  }

  /// Sets the width of the column, held within `columnWidthRange`.
  public func setColumnWidth(_ width: Double, of columnID: String) {
    columnWidths[columnID] = min(max(width, Self.columnWidthRange.lowerBound), Self.columnWidthRange.upperBound)
    onColumnWidthsChanged?(columnWidths)
  }

  /// Gives the column its usual width back.
  public func resetColumnWidth(of columnID: String) {
    columnWidths[columnID] = nil
    onColumnWidthsChanged?(columnWidths)
  }

  /// The longest title in the column's list: of a project's column, its tasks and sub-projects; of a list of tasks,
  /// its tasks. The app measures it to fit the column to its content.
  public func widestTitle(inColumn columnID: String) -> String? {
    let titles: [String]
    if let column = columns.first(where: { $0.id == columnID }) {
      titles = column.entries.map { entry in
        switch entry {
        case .project(let project): project.title
        case .task(let task): task.title
        }
      }
    } else {
      titles = tasks.map(\.title)
    }
    return titles.max { $0.count < $1.count }
  }

  /// How wide a list's column is to be for a title as wide as `titleWidth` to show whole: the title, the cells its
  /// rows show before it and the room round them.
  public func fittedWidth(forTitleWidth titleWidth: Double, inList listID: String) -> Double {
    let cells = ListColumn.allCases.filter { isColumnShown($0, inList: listID) }
    let cellsWidth = cells.reduce(0) { $0 + Self.cellWidth(of: $1) + Self.cellSpacing }
    return titleWidth + cellsWidth + Self.rowInsets
  }

  /// The widths of the cells of a row, as `TaskColumns` has them, and the gap between cells.
  private static func cellWidth(of column: ListColumn) -> Double {
    switch column {
    case .status: 14
    case .duration, .priority: 28
    case .when: 70
    }
  }
  private static let cellSpacing = 4.0
  /// The room a row leaves at either end, for the selection, the scroller and the chevron of a project.
  private static let rowInsets = 48.0
}
