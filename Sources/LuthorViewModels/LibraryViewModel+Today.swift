import Foundation
import LuthorDomain

extension CalendarDate {
  /// Today by the system's calendar and clock; what a window uses unless it is handed another clock.
  public static func systemToday() -> CalendarDate {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    guard let year = parts.year, let month = parts.month, let day = parts.day,
      let today = CalendarDate(year: year, month: month, day: day)
    else { return CalendarDate(daysSinceEpoch: 0) }
    return today
  }
}

// Today: choosing the day shown, planning it, and deciding on its tasks. In its own file (SwiftLint
// file_length) rather than suppressed.
extension LibraryViewModel {
  /// Shows the plan of another day.
  public func showDay(_ date: CalendarDate) {
    planDate = date
    present()
  }

  public func showNextDay() {
    showDay(planDate.adding(days: 1))
  }

  public func showPreviousDay() {
    showDay(planDate.adding(days: -1))
  }

  /// Shows the plan of the day it is by the clock.
  public func showToday() {
    showDay(today)
  }

  /// Plans a task for the day shown. A delegated task is taken back.
  public func addToPlan(_ taskID: TaskID) {
    schedule(taskID, on: planDate)
  }

  /// Plans the selected task for the day shown.
  public func addSelectedToPlan() {
    guard let selected = selection else { return }
    addToPlan(selected)
  }

  /// Takes a task off the day shown; it becomes a candidate again.
  public func removeFromPlan(_ taskID: TaskID) {
    perform { (log) throws(CommandError) in try commands.unschedule(taskID: taskID, log: log) }
  }

  public func removeSelectedFromPlan() {
    guard let selected = selection else { return }
    removeFromPlan(selected)
  }

  /// Moves a task of the plan up (negative) or down (positive) and keeps the whole order as the user's own.
  /// A task that is not in the plan, or that would pass either end, stays where it is.
  public func moveInPlan(_ taskID: TaskID, by offset: Int) {
    let planned = plan.entries.map(\.task.id)
    guard let position = planned.firstIndex(of: taskID), planned.indices.contains(position + offset) else { return }
    var reordered = planned
    reordered.remove(at: position)
    reordered.insert(taskID, at: position + offset)
    let order = reordered
    let viewID = currentView
    let day = planDate
    perform { (log) throws(CommandError) in
      try commands.orderPlan(of: viewID, on: day, as: order, log: log)
    }
  }

  public func moveSelectedInPlan(by offset: Int) {
    guard let selected = selection else { return }
    moveInPlan(selected, by: offset)
  }

  /// Moves a task to the day after the one shown.
  public func deferToTomorrow(_ taskID: TaskID) {
    schedule(taskID, on: planDate.adding(days: 1))
  }

  public func deferSelected() {
    guard let selected = selection else { return }
    deferToTomorrow(selected)
  }

  /// Sets the capacity of the day shown for the current view, or with `nil` falls back to the weekday's.
  public func setDayCapacity(minutes: Int?) {
    let viewID = currentView
    let day = planDate
    perform { (log) throws(CommandError) in try commands.setCapacity(minutes, for: viewID, on: day, log: log) }
  }

  /// Hands a task to someone from today, to come back on `followUp` if there is one. A blank name delegates
  /// nothing.
  public func delegate(_ taskID: TaskID, to name: String, followUp: CalendarDate?) {
    let since = today
    perform { (log) throws(CommandError) in
      try commands.delegate(taskID: taskID, to: name, since: since, followUp: followUp, log: log)
    }
  }

  /// Hands the selected task to someone and selects the one that takes its place.
  public func delegateSelected(to name: String, followUp: CalendarDate?) {
    replaceSelected { delegate($0, to: name, followUp: followUp) }
  }

  /// Takes a delegated task back.
  public func reclaim(_ taskID: TaskID) {
    perform { (log) throws(CommandError) in try commands.reclaim(taskID: taskID, log: log) }
  }

  /// Takes a task off its day and gives it the someday priority.
  public func sendToSomeday(_ taskID: TaskID) {
    perform { (log) throws(CommandError) in try commands.sendToSomeday(taskID: taskID, log: log) }
  }

  /// Sends the selected task to someday and selects the one that takes its place.
  public func sendSelectedToSomeday() {
    replaceSelected(sendToSomeday)
  }

  /// Gives up a task: it leaves every list without being completed.
  public func dropTask(_ taskID: TaskID) {
    perform { (log) throws(CommandError) in try commands.drop(taskID: taskID, log: log) }
  }

  /// Gives up the selected task and selects the one that takes its place.
  public func dropSelected() {
    replaceSelected(dropTask)
  }

  private func schedule(_ taskID: TaskID, on day: CalendarDate) {
    perform { (log) throws(CommandError) in try commands.schedule(taskID: taskID, on: day, log: log) }
  }
}
