import LuthorDomain
import LuthorViewModels
import SwiftUI

/// A session of a task on the day grid: a stretch of its day set apart from the rest. Drag it to another time,
/// or choose Set Times… to change it; Remove Session gives its minutes back to the task.
struct SessionBlockView: View {
  @Environment(\.theme) private var theme
  @Bindable var library: LibraryViewModel
  let slot: SessionSlot
  let hourHeight: CGFloat
  let edit: () -> Void

  var body: some View {
    let task = slot.session.task
    let height = max(CGFloat(slot.session.minutes) * hourHeight / 60 - 2, 24)
    let times = "\(clockText(slot.start))–\(clockText(slot.end))"
    HStack(alignment: .top, spacing: 6) {
      Button {
        library.complete(task.id)
      } label: {
        Image(systemName: "circle")
      }
      .buttonStyle(.plain)
      .help("Complete")
      if height < 44 {
        Text("\(task.title)  \(times)")
          .lineLimit(1)
          .truncationMode(.tail)
      } else {
        VStack(alignment: .leading, spacing: 0) {
          Text(task.title)
            .lineLimit(1)
          Text("\(times) · session")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .frame(height: height, alignment: .top)
    .background(theme.fill.opacity(0.25), in: .rect(cornerRadius: 5))
    .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.fill.opacity(0.6), style: StrokeStyle(dash: [2, 2])))
    .contentShape(.rect)
    .onTapGesture { library.selection = task.id }
    .onDrag {
      library.draggedSessionID = slot.session.id
      library.draggedTaskID = nil
      library.draggedBlockID = nil
      return NSItemProvider(object: Self.payload(slot.session.id) as NSString)
    }
    .contextMenu {
      Button("Set Times…", action: edit)
      Button("Remove Session") { library.removeSession(slot.session.id) }
      Divider()
      DecisionMenuItems(library: library, taskID: task.id)
    }
  }

  /// What a dragged session carries, so a drop on the grid can tell it from a task or a block.
  static func payload(_ id: SessionID) -> String { "session:\(id.rawValue)" }

  /// The session a dropped payload names, if it is one.
  static func sessionID(in payload: String) -> SessionID? {
    payload.hasPrefix("session:") ? SessionID(String(payload.dropFirst("session:".count))) : nil
  }
}

/// Asks when a stretch of a day starts and ends, each with a Now button to fill in the time now.
struct TimesSheet: View {
  @Bindable var library: LibraryViewModel
  let heading: String
  let apply: (Int, Int) -> Void
  @State private var start: Date
  @State private var end: Date
  let close: () -> Void

  init(
    library: LibraryViewModel, heading: String, slot: (start: Int, end: Int), apply: @escaping (Int, Int) -> Void,
    close: @escaping () -> Void
  ) {
    self.library = library
    self.heading = heading
    self.apply = apply
    self.close = close
    _start = State(initialValue: clockDate(minutes: slot.start))
    _end = State(initialValue: clockDate(minutes: slot.end))
  }

  private var isValid: Bool { minutesOfDay(end) > minutesOfDay(start) }

  var body: some View {
    Form {
      Text(heading)
        .font(.headline)
      HStack {
        DatePicker("Starts at", selection: $start, displayedComponents: .hourAndMinute)
        Button("Now") { start = clockDate(minutes: library.minuteOfDay) }
      }
      HStack {
        DatePicker("Ends at", selection: $end, displayedComponents: .hourAndMinute)
        Button("Now") { end = clockDate(minutes: library.minuteOfDay) }
      }
      HStack {
        Spacer()
        Button("Cancel", role: .cancel, action: close)
        Button("OK") {
          apply(minutesOfDay(start), minutesOfDay(end))
          close()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!isValid)
      }
    }
    .padding()
    .frame(width: 300)
  }
}
