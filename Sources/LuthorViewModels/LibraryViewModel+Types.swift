import LuthorDomain

/// What the sidebar can show: the inbox or one active project.
public enum SidebarItem: Hashable, Sendable {
  case inbox
  case project(TaskID)
}

/// The card a window can be editing: one of a task or one of a project.
public enum CardTarget: Hashable, Sendable {
  case task(TaskID)
  case project(TaskID)
}

/// The places the navigation rail leads to, in the order it lists them.
public enum NavigationSection: Hashable, Sendable, CaseIterable {
  case inbox
  case projects
  case priorities
  case today
  case calendar
  case review
  case weeklyReview
  case tags
  case settings
}

/// One entry of a column: a sub-project to open, or a task.
public enum ColumnEntry: Equatable, Sendable, Identifiable {
  case project(Project)
  case task(TaskItem)

  public var id: String {
    switch self {
    case .project(let project): "project-\(project.id.rawValue)"
    case .task(let task): "task-\(task.id.rawValue)"
    }
  }
}

/// One column of the project browser: the top-level projects, or the children of one project.
public struct ProjectColumn: Equatable, Sendable, Identifiable {
  /// The project whose children the column lists; `nil` for the first column, of top-level projects.
  public let parentID: TaskID?
  public let entries: [ColumnEntry]

  public init(parentID: TaskID?, entries: [ColumnEntry]) {
    self.parentID = parentID
    self.entries = entries
  }

  public var id: String {
    parentID.map { "project-\($0.rawValue)" } ?? "top"
  }
}

/// How and when a project is reviewed, as its card in edit mode sets it.
public struct ProjectReviewDraft: Equatable, Sendable {
  /// How often the project is reviewed; `nil` follows the default.
  public var interval: ReviewInterval?
  /// The day to review it next; `nil` leaves the day as the interval works it out.
  public var nextReview: CalendarDate?

  public init(interval: ReviewInterval?, nextReview: CalendarDate?) {
    self.interval = interval
    self.nextReview = nextReview
  }
}

/// A project as the pulldown of a card lists it: indented by how deep it is nested.
public struct ProjectOutlineEntry: Equatable, Sendable, Identifiable {
  public let id: TaskID
  public let title: String
  public let depth: Int
}

/// What a task's card in edit mode holds until OK keeps it.
public struct TaskCardDraft: Equatable, Sendable {
  public var title: String
  public var priority: Priority?
  public var estimate: Int?
  public var due: DueDate?
  /// The day a new task is planned for; `nil` plans it for none. Only a new task's card sets it.
  public var scheduled: CalendarDate?
  public var notes: String
  /// The names of the tags the task is to have, no more and no fewer.
  public var tags: [String]
  /// How the task is to repeat; `nil` for a task that does not.
  public var repeatRule: RepeatRule?
  /// How and when a project is reviewed, as its card sets it; `nil` leaves the review as it is, as for a task.
  public var review: ProjectReviewDraft?

  public init(
    title: String, priority: Priority?, estimate: Int?, due: DueDate?, notes: String, tags: [String] = [],
    repeatRule: RepeatRule? = nil, review: ProjectReviewDraft? = nil, scheduled: CalendarDate? = nil
  ) {
    self.scheduled = scheduled
    self.title = title
    self.priority = priority
    self.estimate = estimate
    self.due = due
    self.notes = notes
    self.tags = tags
    self.repeatRule = repeatRule
    self.review = review
  }

  /// The tag names in text typed as a comma-separated list: no blanks, no leading `@`, and a name given
  /// twice (in any case) counts once, at its first place.
  public static func tagNames(in text: String) -> [String] {
    var names: [String] = []
    for name in text.split(separator: ",").map({ Commands.cleanTagName(String($0)) }) where !name.isEmpty {
      if !names.contains(where: { $0.lowercased() == name.lowercased() }) { names.append(name) }
    }
    return names
  }
}

/// What the plus button at the end of a column can add.
public enum NewItemKind: Hashable, Sendable {
  case task
  case project(ProjectKind)
}

/// An item the plus button of a column started, until OK makes it. The card in the column after the column
/// edits it; nothing is written before OK.
public struct NewItemDraft: Equatable, Sendable {
  /// The project the item is added to; `nil` for a top-level project.
  public internal(set) var parentID: TaskID?
  public internal(set) var kind: NewItemKind
  /// What the card holds so far, the title as typed.
  public internal(set) var card: TaskCardDraft
  /// The priority and estimate the item starts with as a task and as a project: a task takes those of the
  /// project it is in, a top-level project those set in settings.
  /// Which item this is among those begun since launch, so a card can tell a new draft from the one it edits.
  public internal(set) var number = 0
  var taskDefaults: ItemDefaults
  let projectDefaults: ItemDefaults
  /// Whether the user, and not the kind, last set the priority and the estimate: changing the kind leaves
  /// those alone.
  var priorityEdited = false
  var estimateEdited = false

  init(parentID: TaskID?, kind: NewItemKind, taskDefaults: ItemDefaults, projectDefaults: ItemDefaults) {
    self.parentID = parentID
    self.kind = kind
    self.taskDefaults = taskDefaults
    self.projectDefaults = projectDefaults
    card = TaskCardDraft(title: "", priority: nil, estimate: nil, due: nil, notes: "")
    applyKindDefaults()
  }

  /// Gives the priority and estimate the defaults of the kind, a task's or a project's, unless the user set
  /// them.
  mutating func applyKindDefaults() {
    let defaults = kind == .task ? taskDefaults : projectDefaults
    if !priorityEdited { card.priority = defaults.priority }
    if !estimateEdited { card.estimate = defaults.estimate }
  }
}
