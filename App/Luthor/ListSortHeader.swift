import LuthorViewModels
import SwiftUI

/// The sticky header above a list, like the header of a table: a cell above each column of the rows. A click
/// on a cell sorts the list by it, a second click turns the order round, a third goes back to the list's own
/// order. The first cell cycles through Title, Created and Due, ascending and then descending for each. The widths of the trailing cells are those of the cells in `TaskRow`, so each sits over its column.
struct ListSortHeader: View {
  @Bindable var library: LibraryViewModel
  /// The list this header sorts; see `LibraryViewModel.sort(ofList:)`.
  let listID: String

  var body: some View {
    HStack(spacing: 8) {
      cell(library.sortLabelKey(ofList: listID), width: nil, alignment: .leading, firstCell: true)
      cell(.duration, width: TaskColumns.duration, alignment: .trailing)
      cell(.priority, width: TaskColumns.priority, alignment: .center, symbol: "flag")
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 16)
    .padding(.vertical, 4)
    .frame(maxWidth: .infinity)
    .background(.bar)
    .overlay(alignment: .bottom) { Divider() }
  }

  /// A cell of the header; the arrow shows on the one the list is sorted by, pointing down for ascending.
  private func cell(
    _ key: ListSortKey, width: CGFloat?, alignment: Alignment, symbol: String? = nil, firstCell: Bool = false
  ) -> some View {
    let sort = library.sort(ofList: listID)
    return Button {
      if firstCell { library.sortByFirstCell(ofList: listID) } else { library.sortBy(key, ofList: listID) }
    } label: {
      HStack(spacing: 2) {
        if let symbol { Image(systemName: symbol) } else { Text(key.label) }
        if sort.key == key { Image(systemName: sort.ascending ? "chevron.down" : "chevron.up") }
      }
      .frame(maxWidth: width == nil ? .infinity : width, alignment: alignment)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .frame(width: width)
    .help("Sort by \(key.label.lowercased())")
  }
}

/// The widths of the columns a row of a task shows at its end, shared with the header above them.
enum TaskColumns {
  static let duration: CGFloat = 44
  static let priority: CGFloat = 24
}
