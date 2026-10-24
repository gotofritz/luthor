import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The day shown as a day in a calendar: its start and end fields with the zoom buttons, the capacity meter and
/// the planned tasks on an hour grid, each as tall as its estimate. A task stands at the time it was given (drag
/// a candidate onto the grid, drag a block to another time, or Set Start Time…); the others follow one another
/// from the start of the day, or from now on today. Drag a block onto the candidates to take it off the plan.
struct DayCalendarColumn: View {
  @Bindable var library: LibraryViewModel
  @State private var zoom = DayZoom()
  @State private var addingBlock = false

  var body: some View {
    VStack(spacing: 0) {
      PlanReviewToggle(library: library)
        .padding([.horizontal, .top], 12)
        .frame(maxWidth: .infinity, alignment: .leading)
      DayHeader(library: library)
      HStack {
        DayHoursFields(library: library)
        Spacer()
        Button {
          addingBlock = true
        } label: {
          Image(systemName: "calendar.badge.plus")
        }
        .help("Add a block of untracked time, such as lunch")
        Button {
          zoom.zoomOut()
        } label: {
          Image(systemName: "minus.magnifyingglass")
        }
        .disabled(!zoom.canZoomOut)
        .help("Zoom out")
        Button {
          zoom.zoomIn()
        } label: {
          Image(systemName: "plus.magnifyingglass")
        }
        .disabled(!zoom.canZoomIn)
        .help("Zoom in")
      }
      .buttonStyle(.borderless)
      .padding(.horizontal, 12)
      .padding(.bottom, 8)
      CapacityMeter(capacity: library.plan.capacity)
        .padding([.horizontal, .bottom], 12)
      Divider()
      DayGrid(library: library, hourHeight: zoom.hourHeight)
    }
    .sheet(isPresented: $addingBlock) {
      DayBlockSheet(library: library, block: nil, suggestedStart: library.plan.hours.start) { addingBlock = false }
    }
    .frame(width: 420)
  }
}

/// How tall an hour of the grid is: a few steps to zoom between.
private struct DayZoom {
  private static let heights: [CGFloat] = [24, 36, 56, 84, 120]
  private var step = 2

  var hourHeight: CGFloat { Self.heights[step] }
  var canZoomIn: Bool { step < Self.heights.count - 1 }
  var canZoomOut: Bool { step > 0 }

  mutating func zoomIn() {
    if canZoomIn { step += 1 }
  }

  mutating func zoomOut() {
    if canZoomOut { step -= 1 }
  }
}

/// When the day starts and ends: the two fields at the top of the day. Changing one sets the hours of this
/// day alone; the weekday's own come from the settings.
private struct DayHoursFields: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    HStack {
      DatePicker("Start", selection: binding(isStart: true), displayedComponents: .hourAndMinute)
      DatePicker("End", selection: binding(isStart: false), displayedComponents: .hourAndMinute)
    }
  }

  /// One end of the day as a time on the calendar's day; setting it keeps the other end.
  private func binding(isStart: Bool) -> Binding<Date> {
    Binding(
      get: { clockDate(minutes: isStart ? library.plan.hours.start : library.plan.hours.end) },
      set: { picked in
        let minutes = minutesOfDay(picked)
        let hours = library.plan.hours
        library.setDayHours(
          isStart ? DayHours(start: minutes, end: hours.end) : DayHours(start: hours.start, end: minutes))
      })
  }
}

/// A time of day, as minutes after midnight, as a date on today for the date pickers.
func clockDate(minutes: Int) -> Date {
  let midnight = Calendar.current.startOfDay(for: Date())
  return Calendar.current.date(byAdding: .minute, value: minutes, to: midnight) ?? midnight
}

/// The minutes after midnight of a date picked in a date picker.
func minutesOfDay(_ date: Date) -> Int {
  let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
  return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
}

/// The hour grid, scrolled to the start of the day.
private struct DayGrid: View {
  @Environment(\.theme) private var theme
  @Bindable var library: LibraryViewModel
  let hourHeight: CGFloat
  @State private var timingTaskID: TaskID?
  @State private var editingBlock: DayBlock?

  private static let labelWidth: CGFloat = 48

  var body: some View {
    let plan = library.plan
    let slots = library.planSlots
    let firstHour = max(0, min(plan.hours.start, slots.first?.start ?? plan.hours.start) / 60 - 1)
    let lastHour = min(24, (max(plan.hours.end, slots.map(\.end).max() ?? plan.hours.end) + 59) / 60 + 1)
    ScrollViewReader { proxy in
      ScrollView {
        ZStack(alignment: .topLeading) {
          grid(plan.hours, firstHour: firstHour, lastHour: lastHour)
          ForEach(plan.blocks, id: \.id) { dayBlock in
            untracked(dayBlock, firstHour: firstHour)
          }
          ForEach(slots, id: \.entry.task.id) { slot in
            block(slot, firstHour: firstHour)
          }
          if library.planDate == library.today {
            nowLine(firstHour: firstHour)
          }
        }
        .frame(height: CGFloat(lastHour - firstHour) * hourHeight)
        .padding(.trailing, 12)
        .onDrop(
          of: [.text],
          delegate: DayDropDelegate(library: library, firstHour: firstHour, hourHeight: hourHeight))
      }
      .onAppear { proxy.scrollTo(plan.hours.start / 60, anchor: .top) }
    }
    .sheet(item: $editingBlock) { editing in
      DayBlockSheet(library: library, block: editing, suggestedStart: editing.start) { editingBlock = nil }
    }
    .sheet(isPresented: Binding(get: { timingTaskID != nil }, set: { if !$0 { timingTaskID = nil } })) {
      if let taskID = timingTaskID {
        StartTimeSheet(library: library, taskID: taskID, minute: startMinute(of: taskID)) { timingTaskID = nil }
      }
    }
  }

  private func untracked(_ dayBlock: DayBlock, firstHour: Int) -> some View {
    DayBlockView(
      block: dayBlock, hourHeight: hourHeight, edit: { editingBlock = dayBlock },
      delete: { library.removeBlock(dayBlock.id) }, dragStarted: { library.draggedTaskID = nil }
    )
    .padding(.leading, Self.labelWidth + 8)
    .padding(.top, offset(dayBlock.start, firstHour: firstHour))
  }

  private func startMinute(of taskID: TaskID) -> Int {
    library.planSlots.first { $0.entry.task.id == taskID }?.start ?? library.plan.hours.start
  }

  private func offset(_ minute: Int, firstHour: Int) -> CGFloat {
    CGFloat(minute - firstHour * 60) * hourHeight / 60
  }

  /// A row for each hour, with its label, and the hours outside the day shaded.
  private func grid(_ hours: DayHours, firstHour: Int, lastHour: Int) -> some View {
    ZStack(alignment: .topLeading) {
      VStack(spacing: 0) {
        ForEach(firstHour..<lastHour, id: \.self) { hour in
          HStack(alignment: .top, spacing: 6) {
            Text(clockText(hour * 60))
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(width: Self.labelWidth, alignment: .trailing)
            VStack(spacing: 0) {
              Divider()
              Spacer()
            }
          }
          .frame(height: hourHeight)
          .id(hour)
        }
      }
      shade(from: firstHour * 60, to: hours.start, firstHour: firstHour)
      shade(from: hours.end, to: lastHour * 60, firstHour: firstHour)
    }
  }

  private func shade(from start: Int, to end: Int, firstHour: Int) -> some View {
    Rectangle()
      .fill(Color.secondary.opacity(0.08))
      .frame(height: max(0, offset(end, firstHour: firstHour) - offset(start, firstHour: firstHour)))
      .padding(.leading, Self.labelWidth + 6)
      .padding(.top, offset(start, firstHour: firstHour))
      .allowsHitTesting(false)
  }

  /// A red line at the time now, on today.
  private func nowLine(firstHour: Int) -> some View {
    Rectangle()
      .fill(Color.red)
      .frame(height: 1)
      .padding(.leading, Self.labelWidth + 6)
      .padding(.top, max(0, offset(library.minuteOfDay, firstHour: firstHour)))
      .allowsHitTesting(false)
  }

  private func block(_ slot: PlanSlot, firstHour: Int) -> some View {
    let entry = slot.entry
    let isSelected = library.selection == entry.task.id
    let detail = entry.start == nil ? entry.reason : "at a set time"
    return HStack(alignment: .top, spacing: 6) {
      Button {
        library.complete(entry.task.id)
      } label: {
        Image(systemName: "circle")
      }
      .buttonStyle(.plain)
      .help("Complete")
      VStack(alignment: .leading, spacing: 0) {
        Text(entry.task.title)
          .lineLimit(1)
        Text("\(clockText(slot.start))–\(clockText(slot.end)) · \(detail)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .frame(height: max(CGFloat(entry.minutes) * hourHeight / 60 - 2, 24), alignment: .top)
    .background(theme.fill.opacity(isSelected ? 0.45 : 0.25), in: .rect(cornerRadius: 5))
    .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.fill.opacity(0.6)))
    .contentShape(.rect)
    .onTapGesture { library.selection = entry.task.id }
    .onDrag {
      library.draggedTaskID = entry.task.id
      return NSItemProvider(object: entry.task.id.rawValue as NSString)
    }
    .contextMenu {
      if library.planDate == library.today {
        if library.isRunning(entry.task.id) {
          Button("Stop Now") { library.stopNow(entry.task.id) }
        } else {
          Button("Start Now") { library.startNow(entry.task.id) }
        }
      }
      Button("Set Start Time…") { timingTaskID = entry.task.id }
      if entry.start != nil {
        Button("Follow the Other Tasks") { library.place(entry.task.id, atMinute: nil) }
      }
      Button("Back to Candidates") { library.removeFromPlan(entry.task.id) }
      Divider()
      Button("Move Earlier in the Order") { library.moveInPlan(entry.task.id, by: -1) }
      Button("Move Later in the Order") { library.moveInPlan(entry.task.id, by: 1) }
      Divider()
      DecisionMenuItems(library: library, taskID: entry.task.id)
    }
    .padding(.leading, Self.labelWidth + 8)
    .padding(.top, offset(slot.start, firstHour: firstHour))
  }
}

/// Asks what time a planned task starts at, with a Now button to fill in the time now.
private struct StartTimeSheet: View {
  @Bindable var library: LibraryViewModel
  let taskID: TaskID
  @State private var time: Date
  let close: () -> Void

  init(library: LibraryViewModel, taskID: TaskID, minute: Int, close: @escaping () -> Void) {
    self.library = library
    self.taskID = taskID
    self.close = close
    _time = State(initialValue: clockDate(minutes: minute))
  }

  var body: some View {
    Form {
      HStack {
        DatePicker("Starts at", selection: $time, displayedComponents: .hourAndMinute)
        Button("Now") { time = clockDate(minutes: library.minuteOfDay) }
      }
      HStack {
        Spacer()
        Button("Cancel", role: .cancel, action: close)
        Button("OK") {
          library.place(taskID, atMinute: minutesOfDay(time))
          close()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding()
    .frame(width: 300)
  }
}

/// Follows a drag over the hour grid: a dragged task shows where it would land while the others make room, and
/// the drop keeps that.
private struct DayDropDelegate: DropDelegate {
  let library: LibraryViewModel
  let firstHour: Int
  let hourHeight: CGFloat

  private func minute(at location: CGPoint) -> Int {
    max(firstHour * 60 + Int(location.y / hourHeight * 60), 0) / 15 * 15
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    if let dragged = library.draggedTaskID {
      library.dragPreview = (dragged, min(minute(at: info.location), 24 * 60 - 15))
    }
    return DropProposal(operation: .move)
  }

  func dropExited(info: DropInfo) {
    library.dragPreview = nil
  }

  func performDrop(info: DropInfo) -> Bool {
    let minute = minute(at: info.location)
    library.dragPreview = nil
    library.draggedTaskID = nil
    guard let provider = info.itemProviders(for: [.text]).first else { return false }
    _ = provider.loadObject(ofClass: NSString.self) { item, _ in
      guard let dropped = item as? String else { return }
      Task { @MainActor in
        if let blockID = DayBlockView.blockID(in: dropped) {
          library.moveBlock(blockID, toStart: minute)
        } else {
          library.place(TaskID(dropped), atMinute: min(minute, 24 * 60 - 15))
        }
      }
    }
    return true
  }
}
