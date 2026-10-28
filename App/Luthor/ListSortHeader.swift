import LuthorViewModels
import SwiftUI

/// The sticky header above a list, like the header of a table: a cell above each column of the rows. A click
/// on a cell sorts the list by it, a second click turns the order round, a third goes back to the list's own
/// order. The first cell cycles through Title, Created and Due, ascending and then descending for each. The
/// widths of the cells are those of the cells in `TaskRow`, so each sits over its column.
struct ListSortHeader: View {
  @Bindable var library: LibraryViewModel
  /// The list this header sorts; see `LibraryViewModel.sort(ofList:)`.
  let listID: String
  /// Whether the rows have a duration and a priority cell at their end, for the header to sit over.
  var showsStatus = true
  var showsDuration = true
  var showsPriority = true
  /// Room at the end of the rows past the cells above, such as the field of minutes in a review.
  var trailingInset: CGFloat = 0
  /// Whether the header is a row of the list it sorts, as in a section: it then takes the insets of the rows,
  /// and has no bar, divider or padding of its own.
  var isRow = false
  /// The order of the Prios place: done, priority, duration, date, title.
  var priorityFirst = false

  var body: some View {
    HStack(spacing: 8) {
      if showsStatus { statusCell }
      if priorityFirst { priorityCell(separated: showsStatus) }
      if !priorityFirst { titleCell }
      if showsDuration {
        cell(.duration, label: "Duration", width: TaskColumns.duration, alignment: .trailing)
      }
      if library.showsWhenColumn(ofList: listID) {
        cell(.due, label: "When", width: TaskColumns.date, alignment: .leading)
      }
      if showsPriority && !priorityFirst { priorityCell(separated: true) }
      if priorityFirst { titleCell }
      if trailingInset > 0 { Color.clear.frame(width: trailingInset, height: 1) }
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, isRow ? 0 : 16)
    .padding(.vertical, 4)
    .frame(maxWidth: .infinity)
    .background(isRow ? AnyShapeStyle(.clear) : AnyShapeStyle(.bar))
    .overlay(alignment: .bottom) { if !isRow { Divider() } }
  }

  private var titleCell: some View {
    cell(
      library.sortLabelKey(ofList: listID), label: library.firstCellLabel(ofList: listID), width: nil,
      alignment: .leading, firstCell: true, separated: showsStatus || priorityFirst)
  }

  private func priorityCell(separated: Bool) -> some View {
    cell(.priority, label: "Prio", width: TaskColumns.priority, alignment: .center, separated: separated)
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

  /// A cell of the header; the arrow shows on the one the list is sorted by, pointing down for ascending.
  private func cell(
    _ key: ListSortKey, label: String, width: CGFloat?, alignment: Alignment, firstCell: Bool = false,
    separated: Bool = true
  ) -> some View {
    let sort = library.sort(ofList: listID)
    return Button {
      if firstCell { library.sortByFirstCell(ofList: listID) } else { library.sortBy(key, ofList: listID) }
    } label: {
      HStack(spacing: 2) {
        Text(label)
        if sort.key == key { Image(systemName: sort.ascending ? "chevron.down" : "chevron.up") }
      }
      .frame(maxWidth: width == nil ? .infinity : width, alignment: alignment)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .frame(width: width)
    .overlay(alignment: .leading) {
      // Half the gap between the cells, so the dots sit between them without moving them.
      if separated { DottedSeparator().offset(x: -4) }
    }
    .help("Sort by \(label.lowercased())")
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
  static let checkbox: CGFloat = 20
  static let duration: CGFloat = 44
  static let priority: CGFloat = 44
  /// The date a row shows in Prios and Today, the day scheduled for else the due date.
  static let date: CGFloat = 92
}
