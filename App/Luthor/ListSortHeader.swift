import AppKit
import LuthorViewModels
import SwiftUI

/// The sticky header above a list, like the header of a table: a cell above each column of the rows. A click
/// on a cell sorts the list by it, a second click turns the order round, a third goes back to the list's own
/// order. The first cell cycles through Title, Created and Due, ascending and then descending for each. The
/// widths of the cells are those of the cells in `TaskRow`, so each sits over its column.
struct ListSortHeader: View {
  @Bindable var library: LibraryViewModel
  @Environment(\.theme) private var theme
  /// The list this header sorts; see `LibraryViewModel.sort(ofList:)`.
  let listID: String
  /// Whether the rows may have a status, duration and priority cell; the header's menu can turn them off too.
  /// Whether the rows have a duration and a priority cell at their end, for the header to sit over.
  var showsStatus = true
  var showsDuration = true
  var showsPriority = true
  /// Room at the end of the rows past the cells above, such as the field of minutes in a review.
  var trailingInset: CGFloat = 0
  /// Whether the header is a row of the list it sorts, as in a section: it then takes the insets of the rows,
  /// and has no bar, divider or padding of its own.
  var isRow = false
  /// The order of every list but the reviews: done, duration, priority, date, title; false puts the title first.
  var priorityFirst = true
  @State private var showsSettings = false
  /// The width of the column when the drag in progress began.
  @State private var dragStartWidth: Double?

  var body: some View {
    HStack(spacing: TaskColumns.spacing) {
      if shows(.status, showsStatus) { statusCell }
      if !priorityFirst { titleCell }
      if shows(.duration, showsDuration) {
        cell(
          .duration, label: "Duration", symbol: "stopwatch", width: width(.duration), alignment: .trailing,
          resizes: .duration)
      }
      if priorityFirst && shows(.priority, showsPriority) { priorityCell(separated: true) }
      if priorityFirst && library.showsWhenColumn(ofList: listID) {
        cell(.due, label: "When", width: width(.when), alignment: .leading, resizes: .when)
      }
      if shows(.priority, showsPriority) && !priorityFirst { priorityCell(separated: true) }
      if priorityFirst { titleCell }
      if trailingInset > 0 { Color.clear.frame(width: trailingInset, height: 1) }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, isRow ? 0 : 11)
    .padding(.vertical, 4)
    .frame(maxWidth: .infinity)
    .background(isRow ? AnyShapeStyle(.clear) : AnyShapeStyle(.bar))
    .overlay(alignment: .bottom) { Divider() }
    .contentShape(Rectangle())
    .overlay(alignment: .trailing) { if priorityFirst { settingsButton } }
  }

  /// The sliders icon at the far end of the header, which opens the list's settings and keeps them open until a click
  /// lands anywhere else.
  private var settingsButton: some View {
    Button {
      showsSettings.toggle()
    } label: {
      Image(systemName: "slider.horizontal.3")
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(.trailing, isRow ? 0 : 5)
    .help("Columns and completed tasks")
    .accessibilityLabel("List settings")
    .popover(isPresented: $showsSettings, arrowEdge: .bottom) { settingsPopover }
  }

  /// Whether a column of the rows is shown: the lists of the reviews have their own, fixed columns; the others
  /// show what their header's menu has on.
  private func shows(_ column: ListColumn, _ allowed: Bool) -> Bool {
    allowed && (!priorityFirst || library.isColumnShown(column, inList: listID))
  }

  /// A tick beside each column, to turn it on and off, and how far back completed tasks reach; each list
  /// keeps its own.
  private var settingsPopover: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(ListColumn.allCases, id: \.self) { column in
        Toggle(
          column.label,
          isOn: Binding(
            get: { library.isColumnShown(column, inList: listID) },
            set: { _ in library.toggleColumn(column, inList: listID) }))
      }
      Divider()
      Picker(
        "Completed Tasks",
        selection: $library.completedWindow
      ) {
        ForEach(CompletedWindow.allCases, id: \.self) { Text($0.label).tag($0) }
      }
      .fixedSize()
    }
    .padding(12)
  }

  private var titleCell: some View {
    cell(
      library.sortLabelKey(ofList: listID), label: library.firstCellLabel(ofList: listID), width: nil,
      alignment: .leading, firstCell: true, separated: showsStatus || priorityFirst)
  }

  private func priorityCell(separated: Bool) -> some View {
    cell(
      .priority, label: "Prio", width: width(.priority), alignment: .center, separated: separated,
      resizes: .priority)
  }

  /// The cell over the circles of the rows: a triangle, which is the arrow too once the list is sorted by it,
  /// pointing down for open before done and up for the other way round.
  private var statusCell: some View {
    let sort = library.sort(ofList: listID)
    let symbol =
      sort.key == .status
      ? (sort.ascending ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill") : "arrowtriangle.down"
    return Button {
      library.sortBy(.status, ofList: listID)
    } label: {
      Image(systemName: symbol)
        .font(.system(size: 8))
        .frame(width: TaskColumns.checkbox)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("Sort by open and done")
    .accessibilityLabel("Sort by status")
  }

  /// A small triangle, to go above or below a word.
  private func arrow(pointingUp: Bool) -> some View {
    Image(systemName: pointingUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.system(size: 6))
  }

  /// A cell of the header, its text or, with `symbol`, its icon. The one the list is sorted by is in the accent
  /// colour with an arrow: after the word, or, in a `stacked` narrow cell, above it when pointing up and below
  /// it when pointing down. Ascending points down.
  private func cell(
    _ key: ListSortKey, label: String, symbol: String? = nil, width: CGFloat?, alignment: Alignment,
    firstCell: Bool = false, separated: Bool = true, resizes: ListColumn? = nil
  ) -> some View {
    let sort = library.sort(ofList: listID)
    let isSorted = sort.key == key
    let stacked = symbol != nil || resizes == .priority
    return Button {
      if firstCell { library.sortByFirstCell(ofList: listID) } else { library.sortBy(key, ofList: listID) }
    } label: {
      Group {
        if stacked {
          VStack(spacing: 1) {
            arrow(pointingUp: true).opacity(isSorted && !sort.ascending ? 1 : 0)
            if let symbol { Image(systemName: symbol) } else { Text(label) }
            arrow(pointingUp: false).opacity(isSorted && sort.ascending ? 1 : 0)
          }
        } else {
          HStack(spacing: 2) {
            Text(label)
            if isSorted { arrow(pointingUp: !sort.ascending) }
          }
        }
      }
      .foregroundStyle(isSorted ? AnyShapeStyle(theme.ink) : AnyShapeStyle(.secondary))
      .frame(maxWidth: width == nil ? .infinity : width, alignment: alignment)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .frame(width: width)
    .overlay(alignment: .leading) {
      // Half the gap between the cells, so the dots sit between them without moving them.
      if separated { DottedSeparator().offset(x: -TaskColumns.spacing / 2) }
    }
    .overlay(alignment: .trailing) {
      // The last few points of the cell, inside its bounds so the whole strip takes clicks, beside the next cell.
      if priorityFirst, let resizes { resizeHandle(resizes, label: label) }
    }
    .help("Sort by \(label.lowercased())")
  }

  /// The width of the column in the rows: the one dragged to, in the lists whose columns can be resized.
  private func width(_ column: ListColumn) -> CGFloat {
    priorityFirst ? CGFloat(library.columnWidth(column, inList: listID)) : CGFloat(column.defaultWidth)
  }

  /// The strip over the boundary between a column and the next: dragging it resizes the column to its left,
  /// double-clicking it fits the column to its widest content, header included, as in a spreadsheet.
  private func resizeHandle(_ column: ListColumn, label: String) -> some View {
    Color.clear
      .frame(width: 8)
      .frame(maxHeight: .infinity)
      .contentShape(Rectangle())
      .onHover { inside in
        if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
      }
      .highPriorityGesture(
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
          .onChanged { drag in
            let start = dragStartWidth ?? library.columnWidth(column, inList: listID)
            dragStartWidth = start
            library.setColumnWidth(start + drag.translation.width, of: column, inList: listID)
          }
          .onEnded { _ in dragStartWidth = nil }
      )
      .highPriorityGesture(TapGesture(count: 2).onEnded { fit(column, label: label) })
      .help("Drag to resize, double-click to fit")
  }

  /// Sets the column as wide as its widest text or its header, whichever is wider.
  private func fit(_ column: ListColumn, label: String) {
    let font = NSFont.preferredFont(forTextStyle: .caption1)
    func measure(_ text: String?) -> Double {
      text.map { Double(($0 as NSString).size(withAttributes: [.font: font]).width.rounded(.up)) } ?? 0
    }
    // The duration header is an icon, about this wide.
    let header = column == .duration ? 16 : measure(label)
    let content = measure(library.widestText(in: column, inList: listID))
    library.setColumnWidth(max(header, content) + 2, of: column, inList: listID)
  }
}

/// A short vertical line of dots, between two cells of the header.
private struct DottedSeparator: View {
  var body: some View {
    Path { path in
      path.move(to: CGPoint(x: 0, y: 0))
      path.addLine(to: CGPoint(x: 0, y: 14))
    }
    .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [0.5, 3]))
    .frame(width: 1, height: 14)
    .foregroundStyle(.tertiary)
  }
}

/// The widths of the columns a row of a task shows, shared with the header above them.
enum TaskColumns {
  /// The done circle at the start of a row.
  static let checkbox: CGFloat = 14
  /// The duration cell of the review rows, which are not resizable; the other lists take their widths from the view model.
  static let duration: CGFloat = 28
  /// The gap between the cells of a row.
  static let spacing: CGFloat = 4
}
