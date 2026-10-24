import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The day shown as a day in a calendar: its start and end fields with the zoom buttons, the capacity meter and
/// the planned tasks on an hour grid, each as tall as its estimate. A task stands at the time it was given (drag
/// a candidate onto the grid, drag a block to another time, or Set Times…); the others follow one another
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

/// What the times sheet is for: a planned task, a new session of one, or a session it has.
private enum Timing: Identifiable {
  case task(TaskID)
  case newSession(TaskID)
  case session(SessionID)

  var id: String {
    switch self {
    case .task(let id): "task:\(id.rawValue)"
    case .newSession(let id): "new:\(id.rawValue)"
    case .session(let id): "session:\(id.rawValue)"
    }
  }

  var heading: String {
    switch self {
    case .task: "Set Times"
    case .newSession: "Split Off a Session"
    case .session: "Set Times of the Session"
    }
  }
}

/// The hour grid, scrolled to the start of the day.
private struct DayGrid: View {
  @Environment(\.theme) private var theme
  @Bindable var library: LibraryViewModel
  let hourHeight: CGFloat
  @State private var timing: Timing?
  @State private var editingBlock: DayBlock?

  private static let labelWidth: CGFloat = 48

  var body: some View {
    let plan = library.plan
    let slots = library.planSlots
    let sessions = library.planSessions
    let firstStart = min(slots.first?.start ?? plan.hours.start, sessions.first?.start ?? plan.hours.start)
    let firstHour = max(0, min(plan.hours.start, firstStart) / 60 - 1)
    let lastEnd = max(slots.map(\.end).max() ?? 0, sessions.map(\.end).max() ?? 0)
    let lastHour = min(24, (max(plan.hours.end, lastEnd) + 59) / 60 + 1)
    ScrollViewReader { proxy in
      ScrollView {
        ZStack(alignment: .topLeading) {
          grid(plan.hours, firstHour: firstHour, lastHour: lastHour)
          ForEach(library.planBlocks, id: \.id) { dayBlock in
            untracked(dayBlock, firstHour: firstHour)
          }
          ForEach(slots, id: \.entry.task.id) { slot in
            block(slot, firstHour: firstHour)
          }
          ForEach(sessions, id: \.session.id) { slot in
            SessionBlockView(
              library: library, slot: slot, hourHeight: hourHeight, edit: { timing = .session(slot.session.id) }
            )
            .padding(.leading, Self.labelWidth + 8)
            .padding(.top, offset(slot.start, firstHour: firstHour))
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
    .sheet(item: $timing) { target in
      TimesSheet(
        library: library, heading: target.heading, slot: slot(of: target),
        apply: { start, end in apply(target, start: start, end: end) }
      ) { timing = nil }
    }
  }

  private func apply(_ target: Timing, start: Int, end: Int) {
    switch target {
    case .task(let taskID): library.setTimes(taskID, start: start, end: end)
    case .newSession(let taskID): library.addSession(of: taskID, start: start, end: end)
    case .session(let sessionID): library.setSessionTimes(sessionID, start: start, end: end)
    }
  }

  private func untracked(_ dayBlock: DayBlock, firstHour: Int) -> some View {
    DayBlockView(
      block: dayBlock, hourHeight: hourHeight, edit: { editingBlock = dayBlock },
      delete: { library.removeBlock(dayBlock.id) },
      dragStarted: {
        library.draggedTaskID = nil
        library.draggedBlockID = dayBlock.id
        library.draggedSessionID = nil
      }
    )
    .padding(.leading, Self.labelWidth + 8)
    .padding(.top, offset(dayBlock.start, firstHour: firstHour))
  }

  /// The times a sheet starts with: where the task or session stands now, or for a new session, a half hour
  /// from now.
  private func slot(of target: Timing) -> (start: Int, end: Int) {
    switch target {
    case .task(let taskID):
      let slot = library.planSlots.first { $0.entry.task.id == taskID }
      let start = slot?.start ?? library.plan.hours.start
      return (start, slot?.end ?? start + 30)
    case .newSession:
      let start = min((library.minuteOfDay + 14) / 15 * 15, 24 * 60 - 30)
      return (start, start + 30)
    case .session(let sessionID):
      let slot = library.planSessions.first { $0.session.id == sessionID }
      return (slot?.start ?? 0, slot?.end ?? 30)
    }
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
    let height = max(CGFloat(entry.minutes) * hourHeight / 60 - 2, 24)
    return HStack(alignment: .top, spacing: 6) {
      Button {
        library.complete(entry.task.id)
      } label: {
        Image(systemName: "circle")
      }
      .buttonStyle(.plain)
      .help("Complete")
      blockLabel(slot, height: height)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .frame(height: height, alignment: .top)
    .background(theme.fill.opacity(isSelected ? 0.45 : 0.25), in: .rect(cornerRadius: 5))
    .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.fill.opacity(0.6)))
    .contentShape(.rect)
    .onTapGesture { library.selection = entry.task.id }
    .onDrag {
      library.draggedTaskID = entry.task.id
      library.draggedBlockID = nil
      library.draggedSessionID = nil
      return NSItemProvider(object: entry.task.id.rawValue as NSString)
    }
    .contextMenu { blockMenu(entry) }
    .padding(.leading, Self.labelWidth + 8)
    .padding(.top, offset(slot.start, firstHour: firstHour))
  }

  /// The title and times of a planned task: one line, cut off with an ellipsis, in a short block; two in a tall one.
  @ViewBuilder
  private func blockLabel(_ slot: PlanSlot, height: CGFloat) -> some View {
    let entry = slot.entry
    let detail = entry.start == nil ? entry.reason : "at a set time"
    let times = "\(clockText(slot.start))–\(clockText(slot.end))"
    if height < 44 {
      Text("\(entry.task.title)  \(times)")
        .lineLimit(1)
        .truncationMode(.tail)
    } else {
      VStack(alignment: .leading, spacing: 0) {
        Text(entry.task.title)
          .lineLimit(1)
        Text("\(times) · \(detail)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }

  @ViewBuilder
  private func blockMenu(_ entry: PlanEntry) -> some View {
    if library.planDate == library.today {
      if library.isRunning(entry.task.id) {
        Button("Stop Now") { library.stopNow(entry.task.id) }
      } else {
        Button("Start Now") { library.startNow(entry.task.id) }
      }
    }
    Button("Set Times…") { timing = .task(entry.task.id) }
    Button("Split Off a Session…") { timing = .newSession(entry.task.id) }
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
}
