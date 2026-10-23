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
    let height = blockHeight(minutes: slot.session.minutes, hourHeight: hourHeight)
    let times = EstimateScale.label(slot.session.minutes)
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
    .compactBlock(height)
    .frame(height: height, alignment: .top)
    .background(theme.block.opacity(0.4), in: .rect(cornerRadius: 5))
    .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.block.opacity(0.8), style: StrokeStyle(dash: [2, 2])))
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

  private var endMinute: Int { endMinutes(end, after: minutesOfDay(start)) }

  private var isValid: Bool { endMinute > minutesOfDay(start) && endMinute <= library.dayLimit }

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
          apply(minutesOfDay(start), endMinute)
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

/// One time of a day to pick, with a Now button to fill in the time now.
private struct NowTimeRow: View {
  @Bindable var library: LibraryViewModel
  let title: String
  @Binding var time: Date

  var body: some View {
    HStack {
      DatePicker(title, selection: $time, displayedComponents: .hourAndMinute)
      Button("Now") { time = clockDate(minutes: library.minuteOfDay) }
    }
  }
}

/// Splits a planned task in two: A, the part it keeps, from and to; B, the part cut off, from and to. With Defer
/// ticked B is not put on the day but goes back among the candidates as a task of its own, and its times are off.
struct SplitSheet: View {
  @Bindable var library: LibraryViewModel
  let apply: (SplitTimes, Bool) -> Void
  let close: () -> Void
  @State private var aStart: Date
  @State private var aEnd: Date
  @State private var bStart: Date
  @State private var bEnd: Date
  @State private var deferred = false

  init(
    library: LibraryViewModel, times: SplitTimes, apply: @escaping (SplitTimes, Bool) -> Void,
    close: @escaping () -> Void
  ) {
    self.library = library
    self.apply = apply
    self.close = close
    _aStart = State(initialValue: clockDate(minutes: times.aStart))
    _aEnd = State(initialValue: clockDate(minutes: times.aEnd))
    _bStart = State(initialValue: clockDate(minutes: times.bStart))
    _bEnd = State(initialValue: clockDate(minutes: times.bEnd))
  }

  private var times: SplitTimes {
    let aFrom = minutesOfDay(aStart)
    let bFrom = minutesOfDay(bStart)
    return SplitTimes(
      aStart: aFrom, aEnd: endMinutes(aEnd, after: aFrom), bStart: bFrom, bEnd: endMinutes(bEnd, after: bFrom))
  }

  private var isValid: Bool {
    let split = times
    return split.aEnd > split.aStart && split.aEnd <= library.dayLimit
      && (deferred || (split.bEnd > split.bStart && split.bEnd <= library.dayLimit))
  }

  var body: some View {
    Form {
      Text("Split Off a Session")
        .font(.headline)
      NowTimeRow(library: library, title: "A from", time: $aStart)
      NowTimeRow(library: library, title: "A to", time: $aEnd)
      Toggle("Defer: B goes back to the candidates", isOn: $deferred)
      Group {
        NowTimeRow(library: library, title: "B from", time: $bStart)
        NowTimeRow(library: library, title: "B to", time: $bEnd)
      }
      .disabled(deferred)
      HStack {
        Spacer()
        Button("Cancel", role: .cancel, action: close)
        Button("OK") {
          apply(times, deferred)
          close()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!isValid)
      }
    }
    .padding()
    .frame(width: 320)
  }
}
