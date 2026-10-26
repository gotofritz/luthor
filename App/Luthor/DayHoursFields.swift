import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// When the day starts and ends: the two fields at the top of the day, and a Now button that sets the one last
/// picked to the time now. Changing one sets the hours of this day alone; the weekday's own come from the settings.
struct DayHoursFields: View {
  private enum Field { case start, end }

  @Bindable var library: LibraryViewModel
  @FocusState private var focus: Field?
  @State private var picked = Field.start

  var body: some View {
    HStack(spacing: 10) {
      field("Start", .start)
      field("End", .end)
      Button("Now") {
        let now = clockDate(minutes: library.minuteOfDay)
        binding(isStart: picked == .start).wrappedValue = now
      }
      .help("Set the picked time to now")
    }
    .onChange(of: focus) { _, new in
      if let new { picked = new }
    }
  }

  private func field(_ title: String, _ field: Field) -> some View {
    HStack(spacing: 4) {
      Text(title)
        .frame(width: 32, alignment: .trailing)
      DatePicker(title, selection: binding(isStart: field == .start), displayedComponents: .hourAndMinute)
        .labelsHidden()
        .focused($focus, equals: field)
    }
  }

  /// One end of the day as a time on the calendar's day; setting it keeps the other end.
  private func binding(isStart: Bool) -> Binding<Date> {
    Binding(
      get: { clockDate(minutes: isStart ? library.plan.hours.start : library.plan.hours.end) },
      set: { picked in
        let hours = library.plan.hours
        if isStart {
          library.setDayHours(DayHours(start: minutesOfDay(picked), end: hours.end))
        } else {
          let end = endMinutes(picked, after: hours.start)
          if end <= library.dayLimit { library.setDayHours(DayHours(start: hours.start, end: end)) }
        }
      })
  }
}

/// A time of day, as minutes after midnight, as a date on today for the date pickers. Built from the hour and
/// minute on the wall clock, never by adding minutes to midnight: a day that changes to or from summer time is
/// an hour longer or shorter, and that would shift the time by an hour.
func clockDate(minutes: Int) -> Date {
  let calendar = Calendar.current
  let midnight = calendar.startOfDay(for: Date())
  let day = calendar.date(byAdding: .day, value: minutes / (24 * 60), to: midnight) ?? midnight
  let rest = minutes % (24 * 60)
  return calendar.date(bySettingHour: rest / 60, minute: rest % 60, second: 0, of: day) ?? day
}

/// An end picked in a date picker, in minutes after the midnight of the day: one before the start is after
/// midnight, on the day that follows.
func endMinutes(_ date: Date, after start: Int) -> Int {
  let minutes = minutesOfDay(date)
  return minutes < start ? minutes + 24 * 60 : minutes
}

/// The minutes after midnight of a date picked in a date picker.
func minutesOfDay(_ date: Date) -> Int {
  let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
  return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
}
