import LuthorDomain

/// The header of a list, a cell above each column of its rows: how the list is sorted, and the click that
/// changes it. A sort is only how the list is shown, kept while the window is open; it writes nothing to the log.
extension LibraryViewModel {
  /// The ID of the list of tasks beside the columns; each place that has one sorts it apart.
  public var taskListID: String {
    "tasks-\(section)"
  }

  /// How the list is sorted; the order it has until a header is clicked.
  public func sort(ofList listID: String) -> ListSort {
    listSorts[listID] ?? .manual
  }

  /// Sorts the list.
  public func setSort(_ sort: ListSort, ofList listID: String) {
    listSorts[listID] = sort.key == .manual ? nil : sort
    present()
  }

  /// A click on a cell of the header: sorts by its key, ascending; on the key the list is sorted by already,
  /// the other way round; and once more back to the list's own order.
  public func sortBy(_ key: ListSortKey, ofList listID: String) {
    let current = sort(ofList: listID)
    guard current.key == key else { return setSort(ListSort(key: key, ascending: true), ofList: listID) }
    setSort(current.ascending ? ListSort(key: key, ascending: false) : .manual, ofList: listID)
  }

  /// The keys the first cell of the header steps through. A list with a date column of its own, the lists of
  /// a priority and Today's candidates, leaves Due to that column, and a priority's list has no Created.
  private func textKeys(ofList listID: String) -> [ListSortKey] {
    if listID.hasPrefix("priority-") { return [.title] }
    if listID == Self.candidatesListID { return [.title, .created] }
    return [.title, .created, .due]
  }

  /// Whether the rows of the list show a column of dates, the day scheduled for else the due date.
  public func showsWhenColumn(ofList listID: String) -> Bool {
    listID.hasPrefix("priority-") || listID == Self.candidatesListID
  }

  /// The key the first cell shows: the one the list is sorted by if it is among its own, else title.
  public func sortLabelKey(ofList listID: String) -> ListSortKey {
    let key = sort(ofList: listID).key
    return textKeys(ofList: listID).contains(key) ? key : .title
  }

  /// What the first cell says: the key the list is sorted by, or, in its own order, Suggested for Today's
  /// candidates and Title elsewhere.
  public func firstCellLabel(ofList listID: String) -> String {
    if listID == Self.candidatesListID, sort(ofList: listID).key == .manual { return "Suggested" }
    return sortLabelKey(ofList: listID).label
  }

  /// A click on the first cell: sorts by the key it shows, ascending, then descending, and goes on to the next
  /// key; after the last, back to the list's own order. From a sort by another cell it starts at title.
  public func sortByFirstCell(ofList listID: String) {
    let current = sort(ofList: listID)
    let keys = textKeys(ofList: listID)
    guard let position = keys.firstIndex(of: current.key) else {
      return setSort(ListSort(key: .title, ascending: true), ofList: listID)
    }
    if current.ascending { return setSort(ListSort(key: current.key, ascending: false), ofList: listID) }
    let next =
      keys.indices.contains(position + 1)
      ? ListSort(key: keys[position + 1], ascending: true) : .manual
    setSort(next, ofList: listID)
  }

  /// The sub-projects sorted, then the tasks sorted.
  func sorted(_ entries: [ColumnEntry], inList listID: String) -> [ColumnEntry] {
    let sort = sort(ofList: listID)
    let ordered = entries.projectsFirst
    guard sort.key != .manual else { return ordered }
    let projects = ordered.compactMap { entry -> Project? in
      if case .project(let project) = entry { project } else { nil }
    }
    let tasks = ordered.compactMap { entry -> TaskItem? in
      if case .task(let task) = entry { task } else { nil }
    }
    return sort.sorted(projects, by: sortFields).map(ColumnEntry.project)
      + sort.sorted(tasks, by: sortFields).map(ColumnEntry.task)
  }

  /// The tasks of the list beside the columns, sorted.
  func sorted(_ tasks: [TaskItem]) -> [TaskItem] {
    sorted(tasks, inList: taskListID)
  }

  /// The tasks in the sort of the list.
  func sorted(_ tasks: [TaskItem], inList listID: String) -> [TaskItem] {
    sorted(tasks, inList: listID, fields: sortFields(showingWhen: showsWhenColumn(ofList: listID)))
  }

  /// The items in the sort of the list.
  private func sorted<Item>(_ items: [Item], inList listID: String, fields: (Item) -> SortFields) -> [Item] {
    sort(ofList: listID).sorted(items, by: fields)
  }

  /// The candidates of Today, and the leftovers above them, are one list; sorted by the minutes they count for.
  public var sortedCandidates: [PlanEntry] {
    sorted(plan.candidates, inList: Self.candidatesListID, fields: sortFields)
  }

  public var sortedCarryOver: [CarryOverEntry] {
    sorted(carryOver, inList: Self.candidatesListID) { sortFields($0.entry) }
  }

  public static let candidatesListID = "candidates"

  /// The tasks done on the day reviewed, sorted by the minutes they were planned at.
  public var sortedDone: [ReviewEntry] {
    sorted(review.done, inList: "review-done", fields: sortFields)
  }

  /// The tasks not done on the day reviewed.
  public var sortedNotDone: [ReviewEntry] {
    sorted(review.notDone, inList: "review-notdone", fields: sortFields)
  }

  /// The projects due for review.
  public var sortedProjectReview: [ProjectReviewItem] {
    sorted(projectReview, inList: "review-projects") { sortFields($0.project) }
  }

  private func sortFields(_ entry: PlanEntry) -> SortFields {
    SortFields(
      title: entry.task.title, created: entry.task.createdOn, due: listedDate(of: entry.task.id),
      estimate: entry.minutes, priority: entry.task.priority)
  }

  private func sortFields(_ entry: ReviewEntry) -> SortFields {
    SortFields(
      title: entry.task.title, created: entry.task.createdOn, due: state.dueDate(of: entry.task.id)?.date,
      estimate: entry.minutes, priority: entry.task.priority)
  }

  /// The fields of a task; its date is the day it is scheduled for else its due date where the list shows both
  /// in one column.
  private func sortFields(showingWhen: Bool) -> (TaskItem) -> SortFields {
    { [self] task in
      var fields = sortFields(task)
      if showingWhen { fields = fields.withDue(listedDate(of: task.id)) }
      return fields
    }
  }

  private func sortFields(_ task: TaskItem) -> SortFields {
    SortFields(
      title: task.title, created: task.createdOn, due: state.dueDate(of: task.id)?.date,
      estimate: task.estimate, priority: task.priority, isDone: completedTaskIDs.contains(task.id))
  }

  private func sortFields(_ project: Project) -> SortFields {
    SortFields(
      title: project.title, created: project.createdOn, due: state.dueDate(of: project.id)?.date,
      estimate: project.estimate, priority: project.priority, isDone: completedProjectIDs.contains(project.id))
  }
}
