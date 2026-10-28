import LuthorDomain

/// The header of a list, a cell above each column of its rows: how the list is sorted, and the click that changes it. A sort is only how the list is
/// shown, kept while the window is open; it writes nothing to the log.
extension LibraryViewModel {
  /// The ID of the list of tasks beside the columns (the inbox, a tag).
  public static let taskListID = "tasks"

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
    sort(ofList: Self.taskListID).sorted(tasks, by: sortFields)
  }

  private func sortFields(_ task: TaskItem) -> SortFields {
    SortFields(
      title: task.title, created: task.createdOn, due: state.dueDate(of: task.id)?.date,
      estimate: task.estimate, priority: task.priority)
  }

  private func sortFields(_ project: Project) -> SortFields {
    SortFields(
      title: project.title, created: project.createdOn, due: state.dueDate(of: project.id)?.date,
      estimate: project.estimate, priority: project.priority)
  }
}
