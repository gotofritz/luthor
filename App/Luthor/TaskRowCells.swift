import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The cells of a `TaskRow`, each of the width of its column in the header above.
extension TaskRow {
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
    Group {
      if let estimate = task.estimate {
        Text("\(estimate)m")
          .foregroundStyle(.secondary)
          .help("Estimate")
      }
    }
    .frame(width: TaskColumns.duration, alignment: .trailing)
  }

  var dateCell: some View {
    Group {
      if let day = library.listedDate(of: task.id) {
        Text(day.isoString)
          .font(.caption)
          .foregroundStyle(theme.ink)
          .help(library.scheduledDate(of: task.id) == nil ? "Due" : "Scheduled")
      }
    }
    .frame(width: TaskColumns.date, alignment: .leading)
  }

  var priorityCell: some View {
    Group {
      if let priority = task.priority {
        Image(systemName: priority.symbol)
          .foregroundStyle(.secondary)
          .help(priority.title)
      }
    }
    .frame(width: TaskColumns.priority)
  }
}
