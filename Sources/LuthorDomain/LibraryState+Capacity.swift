extension LibraryState {
  /// The minutes the view has on that day: its own for the day, else the weekday's from the settings.
  func capacity(in viewID: ViewID, on date: CalendarDate, planning: Settings) -> Int {
    let weekday = date.weekday
    let own = capacityOverride(in: viewID, on: date)
    return max(0, own ?? planning.capacity[weekday] ?? weekday.builtInCapacityMinutes)
  }
}
