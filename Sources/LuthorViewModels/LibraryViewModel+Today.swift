import Foundation
import LuthorDomain

extension CalendarDate {
  /// Today by the system's clock, in the Gregorian calendar whatever calendar the Mac is set to.
  public static func systemToday() -> CalendarDate {
    today(at: Date(), in: .current, dayChangesAt: 0)
  }

  /// The day it is at an instant: the Gregorian day in the time zone, the new one starting `dayChangesAt` minutes
  /// after midnight, so before then it is still the day before.
  public static func today(at instant: Date, in timeZone: TimeZone, dayChangesAt: Int) -> CalendarDate {
    let calendar = gregorian(in: timeZone)
    let shifted = instant.addingTimeInterval(-Double(dayChangesAt * 60))
    let parts = calendar.dateComponents([.year, .month, .day], from: shifted)
    guard let year = parts.year, let month = parts.month, let day = parts.day,
      let today = CalendarDate(year: year, month: month, day: day)
    else { return CalendarDate(daysSinceEpoch: 0) }
    return today
  }
}

/// The minutes since the start of the day it is at an instant, which begins `dayChangesAt` minutes after midnight:
/// 01:30 is 25:30 of the day before when the day changes at 04:00.
public func minutesSinceDayStart(at instant: Date, in timeZone: TimeZone, dayChangesAt: Int) -> Int {
  let parts = gregorian(in: timeZone).dateComponents([.hour, .minute], from: instant)
  let sinceMidnight = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
  return sinceMidnight >= dayChangesAt ? sinceMidnight : sinceMidnight + 24 * 60
}

private func gregorian(in timeZone: TimeZone) -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = timeZone
  return calendar
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
    shownLayout.slots
  }

  /// The blocks of untracked time of the day shown, where they stand: one dragged over the day is where it
  /// would land, and the ones in its way have moved.
  public var planBlocks: [DayBlock] {
    shownLayout.blocks
  }

  /// The sessions of the day shown, where they stand, as the blocks are.
  public var planSessions: [SessionSlot] {
    shownLayout.sessions
  }

  /// The tasks of the day shown that are done, where they stand: locked, and in the way of what is dropped.
  public var planDone: [PlanSlot] {
    shownLayout.done
  }

  private var shownLayout: DayLayout {
    dayLayout(
      moving: dragPreview?.taskID, to: dragPreview?.minute ?? sessionPreview?.minute ?? 0, block: blockPreview,
      session: sessionPreview?.sessionID)
  }

  /// The one layout of a day, for what is shown while dragging and for what a drop keeps: the tasks and blocks
  /// with `moving` (or the session `session`) laid first at `minute` and `block` laid first, the others making
  /// room. A candidate being dragged counts as planned.
  func dayLayout(moving: TaskID?, to minute: Int, block: DayBlock?, session: SessionID? = nil) -> DayLayout {
    var entries = plan.entries
    if let moving, !entries.contains(where: { $0.task.id == moving }),
      let candidate = plan.candidates.first(where: { $0.task.id == moving })
    {
      entries.append(candidate)
    }
    let shown = DayPlan(
      viewID: plan.viewID, date: plan.date, entries: entries, candidates: plan.candidates,
      capacity: plan.capacity, hours: plan.hours, blocks: plan.blocks, sessions: plan.sessions, done: plan.done)
    return shown.layout(
      notBefore: notBefore, moving: moving, to: minute, movingBlock: block, movingSession: session)
  }

  /// The tasks with a time of their own and the blocks that a change moved, as the events that keep them where
  /// they now are. What was moved itself is left out: its own event says where it is.
  func keepPushed(
    _ after: DayLayout, from before: DayLayout, except movedID: String, on day: CalendarDate, log: [EventEnvelope]
  ) throws(CommandError) -> [EventEnvelope] {
    var events: [EventEnvelope] = []
    for slot in after.slots where slot.entry.task.id.rawValue != movedID && slot.entry.start != nil {
      let was = before.slots.first { $0.entry.task.id == slot.entry.task.id }?.start
      if was != slot.start {
        events += try commands.setStart(taskID: slot.entry.task.id, on: day, minute: slot.start, log: log + events)
      }
    }
    for block in after.blocks where block.id.rawValue != movedID {
      let was = before.blocks.first { $0.id == block.id }?.start
      if was != block.start {
        events += try commands.updateBlock(
          block.id, title: block.title, start: block.start, end: block.end, log: log + events)
      }
    }
    for slot in after.sessions where slot.session.id.rawValue != movedID && !slot.session.isDone {
      let was = before.sessions.first { $0.session.id == slot.session.id }?.start
      if was != slot.start {
        events += try commands.setSession(
          slot.session.id, of: slot.session.task.id, on: day, start: slot.start, minutes: slot.session.minutes,
          log: log + events)
      }
    }
    return events
  }

  var notBefore: Int {
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
    let before = dayLayout(moving: nil, to: 0, block: nil)
    let after = minute.map { dayLayout(moving: taskID, to: $0, block: nil) } ?? before
    perform { (log) throws(CommandError) in
      let placed = try commands.setStart(taskID: taskID, on: day, minute: minute, log: log)
      return try placed + keepPushed(after, from: before, except: taskID.rawValue, on: day, log: log + placed)
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
    let before = dayLayout(moving: nil, to: 0, block: nil)
    let after = dayLayout(moving: nil, to: 0, block: DayBlock(id: blockID, title: title, start: start, end: end))
    perform { (log) throws(CommandError) in
      let changed = try commands.updateBlock(blockID, title: title, start: start, end: end, log: log)
      return try changed + keepPushed(after, from: before, except: blockID.rawValue, on: day, log: log + changed)
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
    let newStart = min(max(start, 0), dayLimit - length)
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
