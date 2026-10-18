/// A tag as the lists show it.
public struct TagItem: Equatable, Sendable, Identifiable {
  public let id: TagID
  public let name: String
  /// The one view the tag belongs to.
  public let viewID: ViewID

  public init(id: TagID, name: String, viewID: ViewID) {
    self.id = id
    self.name = name
    self.viewID = viewID
  }
}

extension LibraryState {
  /// Applies the events that create a tag and put it on a task or take it off.
  mutating func applyTagEvent(_ payload: EventPayload) {
    switch payload {
    case .tagCreated(let created):
      create(created)
    case .taskTagged(let tagged):
      tag(tagged)
    case .taskUntagged(let untagged):
      untag(untagged)
    default:
      break
    }
  }

  /// Ignores a tag that already exists and a view that does not.
  private mutating func create(_ created: TagCreated) {
    guard hasView(created.viewID), !tagItems.contains(where: { $0.id == created.tagID }) else { return }
    tagItems.append(TagItem(id: created.tagID, name: created.name, viewID: created.viewID))
  }

  /// Ignores a task that is not open, a tag that does not exist, and a tag of another view than the task's.
  private mutating func tag(_ tagged: TaskTagged) {
    guard let task = openTasks.first(where: { $0.id == tagged.taskID }),
      let tag = tagItems.first(where: { $0.id == tagged.tagID }),
      tag.viewID == task.viewID
    else { return }
    taskTags[tagged.taskID, default: []].insert(tagged.tagID)
  }

  private mutating func untag(_ untagged: TaskUntagged) {
    guard var carried = taskTags[untagged.taskID] else { return }
    carried.remove(untagged.tagID)
    taskTags[untagged.taskID] = carried.isEmpty ? nil : carried
  }

  /// The tags of a view, in the order they were created.
  public func tags(in viewID: ViewID) -> [TagItem] {
    tagItems.filter { $0.viewID == viewID }
  }

  /// The tags a task carries, in the order they were created.
  public func tags(of taskID: TaskID) -> [TagItem] {
    guard let carried = taskTags[taskID] else { return [] }
    return tagItems.filter { carried.contains($0.id) }
  }

  /// How many open tasks each tag of the view carries; a tag no open task carries counts zero.
  public func taskCounts(ofTagsIn viewID: ViewID) -> [TagID: Int] {
    var counts = Dictionary(uniqueKeysWithValues: tags(in: viewID).map { ($0.id, 0) })
    for task in view(viewID).openTasks {
      for tagID in taskTags[task.id] ?? [] { counts[tagID, default: 0] += 1 }
    }
    return counts
  }

  /// The tag of this view with this name, ignoring case.
  public func tag(named name: String, in viewID: ViewID) -> TagItem? {
    tags(in: viewID).first { $0.name.lowercased() == name.lowercased() }
  }

  /// The open tasks that carry the tag, in capture order; none for a tag that does not exist.
  public func tasks(tagged tagID: TagID) -> [TaskItem] {
    guard let tag = tagItems.first(where: { $0.id == tagID }) else { return [] }
    return view(tag.viewID).openTasks.filter { taskTags[$0.id]?.contains(tagID) ?? false }
  }
}

/// What a list of tasks is narrowed to. A task has to pass every part that is set.
public struct TaskFilter: Equatable, Sendable {
  /// Tags the task has to carry, all of them.
  public var tags: Set<TagID>
  /// The priority the task has to have.
  public var priority: Priority?
  /// The project the task has to be filed in, or in one of its sub-projects.
  public var projectID: ProjectID?
  /// The day the task has to be due on or before, of either kind of due date.
  public var dueBy: CalendarDate?

  public init(
    tags: Set<TagID> = [], priority: Priority? = nil, projectID: ProjectID? = nil, dueBy: CalendarDate? = nil
  ) {
    self.tags = tags
    self.priority = priority
    self.projectID = projectID
    self.dueBy = dueBy
  }

  /// Whether nothing is set, so every task passes.
  public var isEmpty: Bool {
    self == TaskFilter()
  }
}

extension LibraryState {
  /// The open tasks of the view that pass the filter, in capture order.
  public func tasks(in viewID: ViewID, matching filter: TaskFilter) -> [TaskItem] {
    let inProject = filter.projectID.map(subtree(of:))
    return view(viewID).openTasks.filter { matches($0, filter, inProject: inProject) }
  }

  /// Whether the task passes the filter. `inProject` is the projects the filter's project stands for.
  func matches(_ task: TaskItem, _ filter: TaskFilter, inProject: Set<ProjectID>?) -> Bool {
    guard filter.tags.isSubset(of: taskTags[task.id] ?? []) else { return false }
    if let priority = filter.priority, task.priority != priority { return false }
    if let inProject, !(task.projectID.map(inProject.contains) ?? false) { return false }
    if let dueBy = filter.dueBy, !(dueDates[task.id].map { $0.date <= dueBy } ?? false) { return false }
    return true
  }
}
