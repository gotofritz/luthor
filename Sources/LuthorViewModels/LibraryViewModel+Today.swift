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

  /// The planned tasks of the day shown on its hours. On today the ones without a start of their own do not
  /// begin before it is now, rounded up to the quarter hour.
  public var planSlots: [PlanSlot] {
    layout(moving: dragPreview?.taskID, to: dragPreview?.minute ?? 0, block: blockPreview)
  }

  /// The blocks of untracked time of the day shown; one dragged over the day is where it would land.
  public var planBlocks: [DayBlock] {
    plan.blocks.map { $0.id == blockPreview?.id ? (blockPreview ?? $0) : $0 }
  }

  /// The one layout of a day, for what is shown while dragging and for what a drop keeps: the day's slots with
  /// `moving` laid first at `minute` and `block` in place of the block of its ID, the others making room. A
  /// candidate being dragged counts as planned.
  private func layout(moving: TaskID?, to minute: Int, block: DayBlock?) -> [PlanSlot] {
    var entries = plan.entries
    if let moving, !entries.contains(where: { $0.task.id == moving }),
      let candidate = plan.candidates.first(where: { $0.task.id == moving })
    {
      entries.append(candidate)
    }
    let blocks = plan.blocks.map { $0.id == block?.id ? (block ?? $0) : $0 }
    let shown = DayPlan(
      viewID: plan.viewID, date: plan.date, entries: entries, candidates: plan.candidates,
      capacity: plan.capacity, hours: plan.hours, blocks: blocks)
    return shown.slots(notBefore: notBefore, moving: moving, to: minute)
  }

  /// The tasks with a time of their own that a change moved, as the events that keep them where they now are.
  private func keepPushed(
    _ after: [PlanSlot], from before: [PlanSlot], except taskID: TaskID?, on day: CalendarDate, log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    var events: [EventEnvelope] = []
    for slot in after where slot.entry.task.id != taskID && slot.entry.start != nil {
      let was = before.first { $0.entry.task.id == slot.entry.task.id }?.start
      if was != slot.start {
        events += try commands.setStart(taskID: slot.entry.task.id, on: day, minute: slot.start, log: log + events)
      }
    }
    return events
  }

  private var notBefore: Int {
    planDate == today ? (minuteClock() + 14) / 15 * 15 : 0
  }

  /// The minutes since midnight by the clock, for the line that marks now on today's calendar.
  public var minuteOfDay: Int {
    minuteClock()
  }

  /// Plans a task for the day shown, starting at the minute after midnight, or with `nil` following the tasks
  /// before it. Moving a planned task is the same call.
  /// A task put on a start time wins the place: the tasks with a time of their own that it overlaps move to
  /// make room, and keep the places they were given.
  public func place(_ taskID: TaskID, atMinute minute: Int?) {
    let day = planDate
    dragPreview = nil
    let before = layout(moving: nil, to: 0, block: nil)
    let after = minute.map { layout(moving: taskID, to: $0, block: nil) } ?? []
    perform { (log) throws(CommandError) in
      let placed = try commands.setStart(taskID: taskID, on: day, minute: minute, log: log)
      return try placed + keepPushed(after, from: before, except: taskID, on: day, log: log + placed)
    }
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

  /// Sets the hours of the day shown for the current view, or with `nil` falls back to the weekday's.
  /// Hours that do not fit a day change nothing.
  public func setDayHours(_ hours: DayHours?) {
    let viewID = currentView
    let day = planDate
    perform { (log) throws(CommandError) in try commands.setHours(hours, for: viewID, on: day, log: log) }
  }

  /// Puts a block of untracked time, such as lunch, on the day shown. A blank title makes it a Break; hours
  /// that do not fit a day change nothing.
  public func addBlock(title: String, start: Int, end: Int) {
    let viewID = currentView
    let day = planDate
    perform { (log) throws(CommandError) in
      try commands.addBlock(
        title: title, hours: DayHours(start: start, end: end), for: viewID, on: day, log: log)
    }
  }

  /// Changes a block's title and times.
  /// A task with a time of its own that the block now overlaps moves to make room, and keeps its new place.
  public func updateBlock(_ blockID: BlockID, title: String, start: Int, end: Int) {
    let day = planDate
    blockPreview = nil
    let before = layout(moving: nil, to: 0, block: nil)
    let after = layout(moving: nil, to: 0, block: DayBlock(id: blockID, title: title, start: start, end: end))
    perform { (log) throws(CommandError) in
      let changed = try commands.updateBlock(blockID, title: title, start: start, end: end, log: log)
      return try changed + keepPushed(after, from: before, except: nil, on: day, log: log + changed)
    }
  }

  /// Moves a block to start at `start`, keeping its length; it stops at the end of the day.
  public func moveBlock(_ blockID: BlockID, toStart start: Int) {
    guard let moved = block(blockID, movedTo: start) else { return }
    updateBlock(blockID, title: moved.title, start: moved.start, end: moved.end)
  }

  /// Shows a block being dragged at `start`; the tasks around it make room until the drop.
  public func previewBlock(_ blockID: BlockID, toStart start: Int) {
    blockPreview = block(blockID, movedTo: start)
  }

  private func block(_ blockID: BlockID, movedTo start: Int) -> DayBlock? {
    guard let block = plan.blocks.first(where: { $0.id == blockID }) else { return nil }
    let length = block.end - block.start
    let newStart = min(max(start, 0), 24 * 60 - length)
    return DayBlock(id: blockID, title: block.title, start: newStart, end: newStart + length)
  }

  /// Takes a block off the day shown.
  public func removeBlock(_ blockID: BlockID) {
    perform { (log) throws(CommandError) in try commands.removeBlock(blockID, log: log) }
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

  /// The day a task is planned for by hand; `nil` while it is planned for none.
  public func scheduledDate(of taskID: TaskID) -> CalendarDate? {
    state.scheduledDate(of: taskID)
  }

  /// Plans a task for another day than the one shown. A delegated task is taken back.
  public func schedule(_ taskID: TaskID, on day: CalendarDate) {
    perform { (log) throws(CommandError) in try commands.schedule(taskID: taskID, on: day, log: log) }
  }
}
