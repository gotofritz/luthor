import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The Today place: the day shown as a calendar with its hours and capacity meter, beside the candidates to
/// pull in and what is waited for. The calendar and the candidates share the list selection, so the arrow
/// keys walk through both and the Plan menu acts on the task selected.
struct TodayColumnsView: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    HStack(spacing: 0) {
      DayCalendarColumn(library: library)
      Divider()
      CandidatesColumn(library: library)
    }
  }
}

struct DayHeader: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    HStack {
      Button {
        library.showPreviousDay()
      } label: {
        Image(systemName: "chevron.left")
      }
      .help("Previous day")
      Text(title)
        .font(Theme.section)
      Button {
        library.showNextDay()
      } label: {
        Image(systemName: "chevron.right")
      }
      .help("Next day")
      Spacer()
      if library.planDate != library.today {
        Button("Today") { library.showToday() }
      }
      Menu {
        ForEach([0, 120, 240, 360, 480], id: \.self) { minutes in
          Button("\(minutes / 60) hours") { library.setDayCapacity(minutes: minutes) }
        }
        Divider()
        Button("Weekday default") { library.setDayCapacity(minutes: nil) }
      } label: {
        Image(systemName: "clock")
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .help("Capacity of this day")
    }
    .buttonStyle(.borderless)
    .padding(12)
  }

  private var title: String {
    let day = "\(library.planDate.weekday.title) \(library.planDate.isoString)"
    return library.planDate == library.today ? "\(day) · Today" : day
  }
}

/// How much of the day is spoken for: the planned minutes, what is left to plan, and the buffer held back.
/// An overloaded plan turns red and says by how much; it informs and never blocks.
struct CapacityMeter: View {
  @Environment(\.theme) private var theme
  let capacity: DayCapacity

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      GeometryReader { geometry in
        HStack(spacing: 0) {
          Rectangle()
            .fill(capacity.isOverloaded ? Color.red : theme.fill)
            .frame(width: width(of: min(capacity.plannedMinutes, total), in: geometry.size.width))
          Rectangle()
            .fill(theme.fill.opacity(0.15))
            .frame(width: width(of: max(capacity.remainingMinutes, 0), in: geometry.size.width))
          Rectangle()
            .fill(Color.secondary.opacity(0.4))
            .frame(width: width(of: capacity.bufferMinutes, in: geometry.size.width))
            .help("Buffer: protected time for interruptions and the unexpected")
        }
        .clipShape(.rect(cornerRadius: 3))
      }
      .frame(height: 10)
      Text(summary)
        .font(.callout)
        .foregroundStyle(capacity.isOverloaded ? Color.red : Color.primary)
      Text("Buffer \(capacity.bufferMinutes)m held back of \(capacity.availableMinutes)m")
        .font(.caption)
        .foregroundStyle(.secondary)
      if capacity.unestimatedCount > 0 {
        Text("\(capacity.unestimatedCount) unestimated, counted at the default estimate")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  /// The minutes the bar stands for: the day, or more when the plan runs into the buffer.
  private var total: Int {
    max(capacity.availableMinutes, capacity.plannedMinutes + capacity.bufferMinutes, 1)
  }

  private func width(of minutes: Int, in available: CGFloat) -> CGFloat {
    available * CGFloat(minutes) / CGFloat(total)
  }

  private var summary: String {
    if capacity.isOverloaded {
      let planned = "\(capacity.plannedMinutes)m planned, \(capacity.usableMinutes)m usable"
      return "Overloaded by \(-capacity.remainingMinutes)m: \(planned)"
    }
    let left = "\(capacity.remainingMinutes)m left of \(capacity.usableMinutes)m usable"
    return "\(capacity.plannedMinutes)m planned, \(left)"
  }
}

/// What the column beside the day shows: the tasks that could be pulled in, or the delegated ones.
private enum CandidatesMode: String, CaseIterable {
  case candidates = "Candidates"
  case waiting = "Waiting for"
}

/// The tasks that could be pulled into the plan of the day, in the suggested order, or, switched over, the
/// delegated tasks of the view, who has them and since when. Tasks left over from earlier days wait at the
/// top of the candidates for a decision.
private struct CandidatesColumn: View {
  @Bindable var library: LibraryViewModel
  @State private var mode = CandidatesMode.candidates

  var body: some View {
    VStack(spacing: 0) {
      Picker("Show", selection: $mode) {
        ForEach(CandidatesMode.allCases, id: \.self) { mode in
          Text(mode.rawValue).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .padding(12)
      Divider()
      switch mode {
      case .candidates: candidates
      case .waiting: waiting
      }
    }
    .frame(width: 320)
  }

  private var candidates: some View {
    VStack(spacing: 0) {
      ListSortHeader(library: library, listID: LibraryViewModel.candidatesListID)
      candidateList
    }
  }

  private var candidateList: some View {
    List(selection: $library.selection) {
      if !library.carryOver.isEmpty {
        Section("Left over from earlier days") {
          ForEach(library.sortedCarryOver, id: \.entry.task.id) { leftOver in
            PlanRow(library: library, entry: leftOver.entry, kind: .leftOver)
              .tag(leftOver.entry.task.id)
          }
        }
      }
      ForEach(library.sortedCandidates, id: \.task.id) { entry in
        PlanRow(library: library, entry: entry, kind: .candidate)
          .tag(entry.task.id)
      }
    }
    // A task dropped here, from the calendar, goes back to the candidates.
    .dropDestination(for: String.self) { items, _ in
      guard let dropped = items.first else { return false }
      library.removeFromPlan(TaskID(dropped))
      return true
    }
  }

  private var waiting: some View {
    List {
      ForEach(library.waiting, id: \.task.id) { item in
        VStack(alignment: .leading, spacing: 2) {
          Text(item.task.title)
          Text(detail(of: item))
            .font(.caption)
            .foregroundStyle(item.isFollowUpDue ? Color.orange : Color.secondary)
        }
        .contextMenu {
          Button("Reclaim") { library.reclaim(item.task.id) }
        }
      }
    }
  }

  private func detail(of item: WaitingItem) -> String {
    var text = "\(item.delegation.person) since \(item.delegation.since.isoString)"
    if let followUp = item.delegation.followUpDate {
      text += item.isFollowUpDue ? ", follow up now" : ", follow up \(followUp.isoString)"
    }
    return text
  }
}

/// One task of the plan, of the candidates or of the leftovers, with the minutes it counts for and why it
/// sits there.
struct PlanRow: View {
  /// Where the task sits: in the plan of the day shown, among the candidates for it, or left over from an
  /// earlier day.
  enum Kind {
    case planned
    case candidate
    case leftOver
  }

  @Bindable var library: LibraryViewModel
  let entry: PlanEntry
  let kind: Kind

  var body: some View {
    HStack(spacing: 8) {
      Button {
        library.complete(entry.task.id)
      } label: {
        Image(systemName: "circle")
      }
      .buttonStyle(.plain)
      .frame(width: TaskColumns.checkbox)
      .help("Complete")
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.task.title)
        Text(entry.reason)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Text(entry.isUnestimated ? "~\(entry.minutes)m" : "\(entry.minutes)m")
        .foregroundStyle(.secondary)
        .frame(width: TaskColumns.duration, alignment: .trailing)
        .help(entry.isUnestimated ? "Unestimated: counts at the default estimate" : "Estimate")
      Group {
        if let priority = entry.task.priority {
          Image(systemName: priority.symbol)
            .foregroundStyle(.secondary)
            .help(priority.title)
        }
      }
      .frame(width: TaskColumns.priority)
    }
    .draggable(entry.task.id.rawValue)
    .contextMenu {
      switch kind {
      case .planned:
        Button("Move Earlier") { library.moveInPlan(entry.task.id, by: -1) }
        Button("Move Later") { library.moveInPlan(entry.task.id, by: 1) }
        Button("Remove from Plan") { library.removeFromPlan(entry.task.id) }
      case .candidate:
        Button("Add to Plan") { library.addToPlan(entry.task.id) }
      case .leftOver:
        Button("Plan for This Day") { library.addToPlan(entry.task.id) }
        Button("Back to the List") { library.removeFromPlan(entry.task.id) }
      }
      Divider()
      DecisionMenuItems(library: library, taskID: entry.task.id)
    }
  }
}

/// What can be decided about a task that is planned, left over or not done: tomorrow, another day, delegate,
/// someday or drop. Tomorrow and the other days count from the day shown.
struct DecisionMenuItems: View {
  @Bindable var library: LibraryViewModel
  let taskID: TaskID

  /// How many days after the day shown "Another Day" offers, beyond tomorrow.
  private static let laterDays = 2...8

  var body: some View {
    Button("Defer to Tomorrow") { library.deferToTomorrow(taskID) }
    Menu("Another Day") {
      ForEach(Self.laterDays, id: \.self) { offset in
        let day = library.planDate.adding(days: offset)
        Button("\(day.weekday.title) \(day.isoString)") { library.schedule(taskID, on: day) }
      }
    }
    Button("Delegate…") { library.delegatingTaskID = taskID }
    Button("Send to Someday") { library.sendToSomeday(taskID) }
    if library.repeatRule(of: taskID) != nil {
      Button("Skip This One") { library.skip(taskID) }
    }
    Button("Drop Task") { library.dropTask(taskID) }
  }
}

/// Asks whom a task is handed to, and optionally the day to follow up.
struct DelegateSheet: View {
  @Bindable var library: LibraryViewModel
  @State private var name = ""
  @State private var followsUp = false
  @State private var followUpDay = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

  var body: some View {
    Form {
      TextField("Delegate to", text: $name)
        .onSubmit(delegate)
      Toggle("Follow up on a day", isOn: $followsUp)
      if followsUp {
        DatePicker("Follow-up day", selection: $followUpDay, displayedComponents: .date)
      }
      HStack {
        Spacer()
        Button("Cancel", role: .cancel) { library.delegatingTaskID = nil }
        Button("Delegate", action: delegate)
          .keyboardShortcut(.defaultAction)
          .disabled(name.allSatisfy(\.isWhitespace))
      }
    }
    .padding()
    .frame(width: 360)
  }

  private func delegate() {
    guard let taskID = library.delegatingTaskID else { return }
    library.delegate(taskID, to: name, followUp: followsUp ? calendarDate(of: followUpDay) : nil)
    library.delegatingTaskID = nil
  }

  private func calendarDate(of date: Date) -> CalendarDate? {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
    return CalendarDate(year: year, month: month, day: day)
  }
}

/// The toggle between the plan of the day and its review, which are two faces of the same day. It sits in the
/// header of both, and the day shown stays when it is flipped.
struct PlanReviewToggle: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    Picker("Show", selection: Binding(get: { shown }, set: { library.show($0) })) {
      Text("Plan").tag(NavigationSection.today)
      Text("Review").tag(NavigationSection.review)
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .fixedSize()
    .help("Plan the day, or look back on it")
  }

  private var shown: NavigationSection {
    library.section == .review ? .review : .today
  }
}
