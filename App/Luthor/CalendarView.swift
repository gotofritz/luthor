import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The Calendar place: a scrolling list of days, one row across the whole column, and the tasks of the day
/// picked in the next. A mark on a row shows the day has tasks planned for it, and another that tasks are
/// due on it; Sundays have a tinted row. Read-only: planning and deciding stay in Today and Review.
struct CalendarColumnsView: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    HStack(spacing: 0) {
      CalendarDaysColumn(library: library)
      Divider()
      CalendarTasksColumn(library: library)
    }
  }
}

/// The days around today, a month heading before the first of each.
private struct CalendarDaysColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(library.calendarDays) { day in
            if day.date.day == 1 || day.date == library.calendarDays.first?.date {
              MonthHeading(day: day.date)
            }
            CalendarDayRow(
              day: day, isToday: day.date == library.today, isPicked: day.date == library.calendarDate
            ) {
              library.showCalendarDay(day.date)
            }
            .id(day.date)
          }
        }
      }
      .onAppear { proxy.scrollTo(library.calendarDate ?? library.today, anchor: .center) }
    }
    .frame(width: 300)
  }
}

private struct MonthHeading: View {
  let day: CalendarDate

  private static let monthNames = [
    "January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
    "November", "December",
  ]

  var body: some View {
    Text("\(Self.monthNames[day.month - 1]) \(String(day.year))")
      .font(.headline)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.top, 16)
      .padding(.bottom, 4)
  }
}

/// One day: its weekday and date, and a mark with a count for the tasks planned for it and for those due on it.
private struct CalendarDayRow: View {
  let day: CalendarDay
  let isToday: Bool
  let isPicked: Bool
  let pick: () -> Void

  var body: some View {
    Button(action: pick) {
      HStack(spacing: 8) {
        Text("\(day.date.weekday.title) \(day.date.isoString)")
          .fontWeight(isToday ? .bold : .regular)
        if isToday {
          Text("Today")
            .font(.caption)
            .foregroundStyle(Color.accentColor)
        }
        Spacer()
        if day.plannedCount > 0 {
          Label("\(day.plannedCount)", systemImage: "circle.fill")
            .foregroundStyle(Color.accentColor)
            .help("\(day.plannedCount) planned")
        }
        if day.dueCount > 0 {
          Label("\(day.dueCount)", systemImage: "diamond.fill")
            .foregroundStyle(Color.orange)
            .help("\(day.dueCount) due")
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(background)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }

  private var background: Color {
    if isPicked { return Color.accentColor.opacity(0.25) }
    return day.date.weekday == .sunday ? Color.secondary.opacity(0.15) : .clear
  }
}

/// The tasks of the day picked: those planned for it, then those only due on it.
private struct CalendarTasksColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    VStack(spacing: 0) {
      Text(title)
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
      Divider()
      List(selection: $library.selection) {
        ForEach(library.calendarEntries, id: \.task.id) { entry in
          CalendarEntryRow(entry: entry)
            .tag(entry.task.id)
        }
      }
      .overlay {
        if library.calendarEntries.isEmpty {
          Text(library.calendarDate == nil ? "Pick a day" : "Nothing planned or due")
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(width: 320)
  }

  private var title: String {
    library.calendarDate.map { "\($0.weekday.title) \($0.isoString)" } ?? "Tasks"
  }
}

private struct CalendarEntryRow: View {
  let entry: CalendarEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(entry.task.title)
      Text(reasons.joined(separator: " · "))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  /// Why the task is on the day: planned for it, and a deadline or target date on it.
  private var reasons: [String] {
    var reasons: [String] = []
    if entry.isPlanned { reasons.append("Planned") }
    if let due = entry.due { reasons.append(due.isHard ? "Deadline" : "Target date") }
    return reasons
  }
}
