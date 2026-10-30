import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The cells of a `TaskRow`, each of the width of its column in the header above.
extension TaskRow {
  /// How wide the column is in this row's list, as the header over it has been dragged to.
  func width(_ column: ListColumn) -> CGFloat {
    listID.map { CGFloat(library.columnWidth(column, inList: $0)) } ?? CGFloat(column.defaultWidth)
  }

  var titleCells: some View {
    HStack(spacing: 8) {
      Text(task.title)
        .strikethrough(isCompleted)
        .foregroundStyle(titleStyle)
      if let tags = tagLine(of: library.tagItems(of: task.id)) {
        Text(tags)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
    }
  }

  var durationCell: some View {
    ZStack(alignment: .trailing) {
      Color.clear.frame(height: 1)
      if let estimate = task.estimate {
        Text("\(estimate)m")
          .font(.caption)
          .foregroundStyle(.secondary)
          .help("Estimate")
      }
    }
    .frame(width: width(.duration), alignment: .trailing)
  }

  var dateCell: some View {
    ZStack(alignment: .leading) {
      Color.clear.frame(height: 1)
      if let day = library.listedDate(of: task.id) {
        Text(day.isoString)
          .font(.caption)
          .foregroundStyle(theme.ink)
          .help(library.scheduledDate(of: task.id) == nil ? "Due" : "Scheduled")
      }
    }
    .frame(width: width(.when), alignment: .leading)
  }

  var priorityCell: some View {
    ZStack {
      Color.clear.frame(height: 1)
      if let priority = task.priority {
        Image(systemName: priority.symbol)
          .foregroundStyle(.secondary)
          .help(priority.title)
      }
    }
    .frame(width: width(.priority))
  }
}
