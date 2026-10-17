import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The Today place: the plan of the day shown with its capacity meter, the candidates to pull in, and
/// what is waited for. The plan and the candidates share the list selection, so the arrow keys walk
/// through both and the Plan menu acts on the task selected.
struct TodayColumnsView: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    HStack(spacing: 0) {
      PlanColumn(library: library)
      Divider()
      CandidatesColumn(library: library)
      Divider()
      WaitingColumn(library: library)
    }
  }
}

/// The day shown, its capacity meter and the ordered plan.
private struct PlanColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    VStack(spacing: 0) {
      DayHeader(library: library)
      CapacityMeter(capacity: library.plan.capacity)
        .padding([.horizontal, .bottom], 12)
      Divider()
      List(selection: $library.selection) {
        ForEach(library.plan.entries, id: \.task.id) { entry in
          PlanRow(library: library, entry: entry, isPlanned: true)
            .tag(entry.task.id)
        }
      }
    }
    .frame(width: 380)
  }
}

private struct DayHeader: View {
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
        .font(.headline)
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
private struct CapacityMeter: View {
  let capacity: DayCapacity

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      GeometryReader { geometry in
        HStack(spacing: 0) {
          Rectangle()
            .fill(capacity.isOverloaded ? Color.red : Color.accentColor)
            .frame(width: width(of: min(capacity.plannedMinutes, total), in: geometry.size.width))
          Rectangle()
            .fill(Color.accentColor.opacity(0.15))
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

/// The tasks that could be pulled into the plan of the day, in the suggested order.
private struct CandidatesColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    VStack(spacing: 0) {
      Text("Candidates")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
      Divider()
      List(selection: $library.selection) {
        ForEach(library.plan.candidates, id: \.task.id) { entry in
          PlanRow(library: library, entry: entry, isPlanned: false)
            .tag(entry.task.id)
        }
      }
    }
    .frame(width: 320)
  }
}

/// The delegated tasks of the view, who has them and since when.
private struct WaitingColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    VStack(spacing: 0) {
      Text("Waiting for")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
      Divider()
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
    .frame(width: 260)
  }

  private func detail(of item: WaitingItem) -> String {
    var text = "\(item.delegation.person) since \(item.delegation.since.isoString)"
    if let followUp = item.delegation.followUpDate {
      text += item.isFollowUpDue ? ", follow up now" : ", follow up \(followUp.isoString)"
    }
    return text
  }
}

/// One task of the plan or of the candidates, with the minutes it counts for and why it sits there.
private struct PlanRow: View {
  @Bindable var library: LibraryViewModel
  let entry: PlanEntry
  /// Whether the task is in the plan of the day shown, rather than a candidate for it.
  let isPlanned: Bool

  var body: some View {
    HStack(spacing: 8) {
      Button {
        library.complete(entry.task.id)
      } label: {
        Image(systemName: "circle")
      }
      .buttonStyle(.plain)
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
        .help(entry.isUnestimated ? "Unestimated: counts at the default estimate" : "Estimate")
      if let priority = entry.task.priority {
        Image(systemName: priority.symbol)
          .foregroundStyle(.secondary)
          .help(priority.title)
      }
    }
    .contextMenu {
      if isPlanned {
        Button("Move Earlier") { library.moveInPlan(entry.task.id, by: -1) }
        Button("Move Later") { library.moveInPlan(entry.task.id, by: 1) }
        Button("Remove from Plan") { library.removeFromPlan(entry.task.id) }
      } else {
        Button("Add to Plan") { library.addToPlan(entry.task.id) }
      }
      Divider()
      Button("Defer to Tomorrow") { library.deferToTomorrow(entry.task.id) }
      Button("Delegate…") { library.delegatingTaskID = entry.task.id }
      Button("Send to Someday") { library.sendToSomeday(entry.task.id) }
      Button("Drop Task") { library.dropTask(entry.task.id) }
    }
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
