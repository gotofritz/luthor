import LuthorDomain
import LuthorViewModels
import SwiftUI

/// A task that is done, on the day grid where it stood: greyed and locked, so it cannot be dragged and nothing
/// can be dropped on it. The tick reopens it.
struct DoneBlockView: View {
  @Bindable var library: LibraryViewModel
  let task: TaskItem
  let start: Int
  let end: Int
  let hourHeight: CGFloat

  var body: some View {
    let height = blockHeight(minutes: end - start, hourHeight: hourHeight)
    HStack(alignment: .top, spacing: 6) {
      Button {
        library.reopen(task.id)
      } label: {
        Image(systemName: "checkmark.circle.fill")
      }
      .buttonStyle(.plain)
      .help("Done: click to reopen")
      Text("\(task.title)  \(EstimateScale.label(end - start))")
        .strikethrough()
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 0)
    }
    .foregroundStyle(.secondary)
    .padding(.horizontal, 6)
    .compactBlock(height)
    .frame(height: height, alignment: .top)
    .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 5))
    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.secondary.opacity(0.3)))
    .contentShape(.rect)
    .contextMenu {
      Button("Reopen") { library.reopen(task.id) }
    }
  }
}
