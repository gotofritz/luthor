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

/// The views and the settings: every view, the one the settings place is editing, the settings with no override and
/// those `currentView` plans with, and the settings of every view for a screen that shows one other than the view shown.
@MainActor
@Observable
final class SettingsModel {
  var views: [ViewItem] = []
  var viewBeingEdited: ViewID?
  var globalSettings = LibraryState.replay([]).globalSettings
  var viewSettings = LibraryState.replay([]).settings(for: .default)
  var settingsByView: [ViewID: Settings] = [:]
  var overriddenKeysByView: [ViewID: Set<SettingKey>] = [:]
  var defaultViewID = ViewID.default
}

/// The project browser: every active project of the view, those a card can name, the project shown and its path, the
/// columns, and how each list is sorted by its header bar.
@MainActor
@Observable
final class BrowserModel {
  var projects: [Project] = []
  var knownProjects: [Project] = []
  var shownProject: Project?
  var columns: [ProjectColumn] = []
  var path: [TaskID] = []
  var listSorts: [String: ListSort] = [:]
  var listColumns: [String: Set<ListColumn>] = [:]
  /// The widths the columns of the browser were dragged to, by column.
  var columnWidths: [String: Double] = [:]
}

/// The tasks listed, those of them that can be worked on now, and the completed and dropped items listed beside
/// them, with those that can be reopened.
@MainActor
@Observable
final class ListedModel {
  var tasks: [TaskItem] = []
  var nextActions: Set<TaskID> = []
  var completedTaskIDs: Set<TaskID> = []
  var completedProjectIDs: Set<TaskID> = []
  var droppedTaskIDs: Set<TaskID> = []
  var droppedProjectIDs: Set<TaskID> = []
  var reopenableTaskIDs: Set<TaskID> = []
  var reopenableProjectIDs: Set<TaskID> = []
}

/// What is picked and what is being edited: the selected task or tasks, the card open, the item being added, and the
/// task the Delegate dialog asks about.
@MainActor
@Observable
final class SelectionModel {
  var selection: TaskID?
  var multiSelection: Set<TaskID> = []
  var projectCardOpen = false
  var editingCard: CardTarget?
  var newItem: NewItemDraft?
  var newItemsStarted = 0
  var delegatingTaskID: TaskID?
}
