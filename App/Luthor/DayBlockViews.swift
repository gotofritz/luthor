import LuthorDomain
import LuthorViewModels
import SwiftUI

/// A block of untracked time on the day grid, such as lunch: grey rather than the accent, so it reads as time
/// the plan keeps clear. Drag it to another time; double-click or Edit… changes it, Delete takes it off.
struct DayBlockView: View {
  let block: DayBlock
  let hourHeight: CGFloat
  let edit: () -> Void
  let delete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(block.title)
        .lineLimit(1)
      Text("\(clockText(block.start))–\(clockText(block.end))")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(height: max(CGFloat(block.end - block.start) * hourHeight / 60 - 2, 24), alignment: .top)
    .background(Color.gray.opacity(0.28), in: .rect(cornerRadius: 5))
    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.6), style: StrokeStyle(dash: [4, 3])))
    .contentShape(.rect)
    .onTapGesture(count: 2, perform: edit)
    .draggable(DayBlockView.payload(block.id))
    .contextMenu {
      Button("Edit…", action: edit)
      Button("Delete", role: .destructive, action: delete)
    }
  }

  /// What a dragged block carries, so a drop on the grid can tell it from a task.
  static func payload(_ id: BlockID) -> String { "block:\(id.rawValue)" }

  /// The block a dropped payload names, if it is one.
  static func blockID(in payload: String) -> BlockID? {
    payload.hasPrefix("block:") ? BlockID(String(payload.dropFirst("block:".count))) : nil
  }
}

/// Asks for the title and times of a new block, or changes the one given.
struct DayBlockSheet: View {
  @Bindable var library: LibraryViewModel
  let block: DayBlock?
  @State private var title: String
  @State private var start: Date
  @State private var end: Date
  let close: () -> Void

  init(library: LibraryViewModel, block: DayBlock?, suggestedStart: Int, close: @escaping () -> Void) {
    self.library = library
    self.block = block
    self.close = close
    _title = State(initialValue: block?.title ?? "")
    _start = State(initialValue: clockDate(minutes: block?.start ?? suggestedStart))
    _end = State(initialValue: clockDate(minutes: block?.end ?? min(suggestedStart + 60, 24 * 60 - 1)))
  }

  var body: some View {
    Form {
      TextField("What", text: $title, prompt: Text("Lunch"))
      DatePicker("From", selection: $start, displayedComponents: .hourAndMinute)
      DatePicker("To", selection: $end, displayedComponents: .hourAndMinute)
      HStack {
        if let block {
          Button("Delete", role: .destructive) {
            library.removeBlock(block.id)
            close()
          }
        }
        Spacer()
        Button("Cancel", role: .cancel, action: close)
        Button(block == nil ? "Add" : "OK") {
          if let block {
            library.updateBlock(block.id, title: title, start: minutesOfDay(start), end: minutesOfDay(end))
          } else {
            library.addBlock(title: title, start: minutesOfDay(start), end: minutesOfDay(end))
          }
          close()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding()
    .frame(width: 320)
  }
}
