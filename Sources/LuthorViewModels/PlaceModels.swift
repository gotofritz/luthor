import LuthorDomain
import Observation

// The state of the places that have a lot of it of their own, each in a class of its own so a view that reads one
// is told only of changes there. `LibraryViewModel` holds one of each and forwards their properties
// (LibraryViewModel+Places.swift), so views and tests read them as before.

/// What Today, the day calendar and the review show: the day, its plan, and the drag in progress.
@MainActor
@Observable
final class DayModel {
  /// The day it is by the clock as of the last refresh, the day whose plan Today shows, that plan (planned
  /// tasks, candidates, capacity) for the current view, and the view's delegated tasks, longest wait first.
  var today: CalendarDate
  var planDate: CalendarDate
  var plan: DayPlan
  var waiting: [WaitingItem] = []
  /// The review of the day shown, and the open tasks planned for an earlier day than today, which wait at
  /// the top of Today until each is decided.
  var review: DayReview
  var carryOver: [CarryOverEntry] = []
  /// The calendar's days around today with their marks, the day picked on it (`nil` until one is) and that
  /// day's tasks: the ones planned for it, then those only due on it.
  var calendarDays: [CalendarDay] = []
  var calendarDate: CalendarDate?
  var calendarEntries: [CalendarEntry] = []
  /// The task, block and session being dragged on the day calendar, set when the drag starts.
  var draggedTaskID: TaskID?
  var draggedBlockID: BlockID?
  var draggedSessionID: SessionID?
  /// While something is dragged over the day, where it would land: the others show making room.
  var sessionPreview: (sessionID: SessionID, minute: Int)?
  var blockPreview: DayBlock?
  var dragPreview: (taskID: TaskID, minute: Int)?

  init(view: ViewID, day: CalendarDate) {
    today = day
    planDate = day
    plan = LibraryState.replay([]).plan(for: view, on: day, today: day)
    review = LibraryState.replay([]).dayReview(for: view, on: day, today: day)
  }
}

/// The tags of the view in creation order, how many open tasks each carries, and the one picked in the Tags place
/// (`nil` until one is), whose open tasks that place lists.
@MainActor
@Observable
final class TagsModel {
  var tags: [TagItem] = []
  var tagTaskCounts: [TagID: Int] = [:]
  var selectedTagID: TagID?
}

/// The weekly review: the projects of the view whose review is due, the longest overdue first, the one picked
/// (`nil` while none is due), and how often projects are reviewed unless they say otherwise.
@MainActor
@Observable
final class WeeklyReviewModel {
  var projectReview: [ProjectReviewItem] = []
  var reviewProjectID: TaskID?
  var reviewDefault = ReviewInterval.weekly
}
