import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The Miller columns of the place the navigation rail has picked. The inbox is a list of its tasks. Today
/// is the plan of a day, its candidates and the tasks waited for. The calendar is a list of days and the tasks
/// of the one picked. Review is the day looked back on. The weekly review is the projects due for review, the one
/// picked with its card, and its tasks. The
/// projects are the top-level projects first, then one column for each project on the way to the one shown, listing its sub-projects and tasks
/// in the order they were added and ended by a plus button that adds to it. The pencil on a project's row swaps
/// the list of its children for its card. The
/// last column is the card of the item being added, else of the task picked or, while its pencil is pressed, of the project shown. The priorities are the four
/// priorities and no priority, picked like the rows of any
/// list, then a list of the tasks for each one picked, ended by a plus button that adds a task with that priority. The tags are the view's tags, then the tasks that carry the
/// one picked. Tasks that are not next actions are dimmed. Drag a task onto a
/// project to file it, a project onto another to nest it, or onto a column to move it into that column's
/// project; the first column makes it top-level.
struct ColumnBrowserView: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        HStack(spacing: 0) {
          columns(revealing: proxy)
          if library.section != .settings {
            cardColumn
          }
        }
      }
    }
  }

  /// Whether the card of the project shown stands in for the column that lists its children.
  private func isReplacedByCard(_ column: ProjectColumn) -> Bool {
    library.projectCardOpen && column.parentID != nil && column.parentID == library.shownProject?.id
  }

  @ViewBuilder
  private func columns(revealing proxy: ScrollViewProxy) -> some View {
    switch library.section {
    case .inbox:
      TaskListColumn(library: library)
      Divider()
    case .today:
      TodayColumnsView(library: library)
      Divider()
    case .calendar:
      CalendarColumnsView(library: library)
      Divider()
    case .review:
      ReviewColumnsView(library: library)
      Divider()
    case .weeklyReview:
      WeeklyReviewColumnsView(library: library)
      Divider()
    case .projects:
      ForEach(Array(library.columns.enumerated()), id: \.element.id) { position, column in
        if !isReplacedByCard(column) {
          ColumnView(library: library, column: column, position: position) {
            withAnimation { proxy.scrollTo(column.id, anchor: .leading) }
          }
          .id(column.id)
          Divider()
        }
      }
    case .priorities:
      PriorityColumn(library: library)
      Divider()
      TaskListColumn(library: library)
      Divider()
    case .tags:
      TagColumn(library: library)
      Divider()
      TaskListColumn(library: library)
      Divider()
    case .settings:
      SettingsColumnsView(library: library)
      Divider()
    }
  }

  /// The card of the item being added, else of the task picked, or of the project shown.
  @ViewBuilder
  private var cardColumn: some View {
    if let item = library.newItem {
      NewItemCardColumn(library: library, item: item)
      Divider()
    } else {
      pickedCardColumn
    }
  }

  @ViewBuilder
  private var pickedCardColumn: some View {
    switch library.cardTarget {
    case .task:
      if let task = library.selectedTask {
        TaskCardColumn(library: library, task: task)
        Divider()
      }
    case .project:
      if let project = library.shownProject {
        ProjectCardColumn(library: library, project: project)
        Divider()
      }
    case nil:
      EmptyView()
    }
  }
}

/// The tasks of the inbox, of the tag picked, or of the project the weekly review picked; for the priorities
/// picked, a list for each (`PriorityListsColumn`).
struct TaskListColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    if library.section == .priorities {
      PriorityListsColumn(library: library)
    } else {
      VStack(spacing: 0) {
        if library.section == .inbox || library.section == .tags || library.section == .weeklyReview {
          ListSortHeader(library: library, listID: library.taskListID)
        }
        List(selection: $library.selection) {
          ForEach(library.tasks, id: \.id) { task in
            TaskRow(library: library, task: task)
              .tag(task.id)
          }
        }
      }
      .frame(width: 320)
    }
  }
}

struct ProjectRow: View {
  @Bindable var library: LibraryViewModel
  let project: Project
  @State private var confirmingDelete = false

  private var isCompleted: Bool {
    library.completedProjectIDs.contains(project.id)
  }

  /// Swaps the list of the project's children for its card, and back.
  private var pencil: some View {
    let isOpen = library.projectCardOpen && library.shownProject?.id == project.id
    return Button {
      library.toggleProjectCard(project.id)
    } label: {
      Image(systemName: "pencil")
        .padding(4)
        .background(isOpen ? Color.accentColor.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 5))
    }
    .buttonStyle(.plain)
    .help(isOpen ? "Show the list of this project" : "Show the card of this project")
    .accessibilityLabel("Edit")
  }

  var body: some View {
    HStack {
      Label(project.title, systemImage: project.kind.symbol)
        .strikethrough(isCompleted)
        .foregroundStyle(isCompleted ? .secondary : .primary)
      if library.droppedProjectIDs.contains(project.id) {
        Image(systemName: "xmark.circle")
          .foregroundStyle(.secondary)
          .help("Dropped")
      }
      Spacer()
      if library.path.contains(project.id) {
        pencil
      }
      Image(systemName: "chevron.right")
        .foregroundStyle(.secondary)
    }
    // The whole row, spacer included, is what a drag picks up. The drop lives on the row in the column
    // (ColumnView), not here: one view that is both dragged and dropped on never starts a drag in a List.
    .contentShape(Rectangle())
    .draggable(LibraryViewModel.dragPayload(for: project.id))
    .contextMenu {
      if isCompleted {
        if library.reopenableProjectIDs.contains(project.id) {
          Button("Reopen Project") { library.reopenProject(project.id) }
        }
      } else {
        Button("Complete Project") { library.completeProject(project.id) }
        ItemFieldMenuItems(library: library, taskID: project.id)
        Menu("Kind") {
          Button("Parallel", systemImage: ProjectKind.parallel.symbol) {
            library.setKind(of: project.id, to: .parallel)
          }
          .disabled(project.kind == .parallel)
          Button("Sequential", systemImage: ProjectKind.sequential.symbol) {
            library.setKind(of: project.id, to: .sequential)
          }
          .disabled(project.kind == .sequential)
        }
        if project.children.isEmpty {
          Button("Turn into Task") { library.turnIntoTask(project.id) }
            .help("Turn this empty project back into a task")
        }
        ProjectReviewMenuItems(library: library, project: project)
        if project.parentID != nil {
          Button("Move to Top Level") { library.nest(project.id, under: nil) }
        }
        Menu("Move to View") {
          ForEach(library.views.filter { $0.id != library.currentView }, id: \.id) { view in
            Button(view.name) { library.moveProject(project.id, toView: view.id) }
          }
        }
        .disabled(library.views.count < 2)
      }
      Divider()
      Button("Delete Permanently…", role: .destructive) { confirmingDelete = true }
    }
    .confirmationDialog("Delete “\(project.title)” permanently?", isPresented: $confirmingDelete) {
      Button("Delete", role: .destructive) { library.deleteProject(project.id) }
    } message: {
      Text("The project, its sub-projects and every task in them are removed for good.")
    }
  }
}

struct TaskRow: View {
  @Bindable var library: LibraryViewModel
  let task: TaskItem
  /// Whether the priority shows as an icon, and the date (scheduled, else due) as text; the priorities place
  /// lists by priority and shows when each task is wanted.
  var showsPriority = true
  var showsDate = false
  @Environment(\.theme) private var theme
  @State private var confirmingDelete = false

  private var isCompleted: Bool {
    library.completedTaskIDs.contains(task.id)
  }

  private var isNextAction: Bool {
    library.nextActions.contains(task.id)
  }

  /// A completed occurrence of a repeating task is in a lighter accent, so it reads as done for now.
  private var isDoneOccurrence: Bool {
    isCompleted && library.repeatRule(of: task.id) != nil
  }

  private var titleStyle: AnyShapeStyle {
    if isDoneOccurrence { return AnyShapeStyle(theme.ink.opacity(0.55)) }
    return isNextAction && !isCompleted ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary)
  }

  var body: some View {
    HStack(spacing: 8) {
      checkbox
        .frame(width: TaskColumns.checkbox)
      Text(task.title)
        .strikethrough(isCompleted)
        .foregroundStyle(titleStyle)
      if let tags = tagLine(of: library.tagItems(of: task.id)) {
        Text(tags)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      Group {
        if let estimate = task.estimate {
          Text("\(estimate)m")
            .foregroundStyle(.secondary)
            .help("Estimate")
        }
      }
      .frame(width: TaskColumns.duration, alignment: .trailing)
      if showsDate, let day = library.listedDate(of: task.id) {
        Text(day.isoString)
          .foregroundStyle(theme.ink)
          .help(library.scheduledDate(of: task.id) == nil ? "Due" : "Scheduled")
      }
      if showsPriority {
        Group {
          if let priority = task.priority {
            Image(systemName: priority.symbol)
              .foregroundStyle(.secondary)
              .help(priority.title)
          }
        }
        .frame(width: TaskColumns.priority)
      }
    }
    .draggable(task.id.rawValue)
    .contextMenu { menu }
    .confirmationDialog("Delete “\(task.title)” permanently?", isPresented: $confirmingDelete) {
      Button("Delete", role: .destructive) { library.deleteTask(task.id) }
    } message: {
      Text("The task is removed for good.")
    }
  }

  /// Completes the task; on a completed task that can be reopened, reopens it.
  @ViewBuilder
  private var checkbox: some View {
    if isCompleted {
      Button {
        library.reopen(task.id)
      } label: {
        Image(systemName: library.droppedTaskIDs.contains(task.id) ? "xmark.circle.fill" : "checkmark.circle.fill")
          .foregroundStyle(isDoneOccurrence ? AnyShapeStyle(theme.ink.opacity(0.55)) : AnyShapeStyle(.primary))
      }
      .buttonStyle(.plain)
      .disabled(!library.reopenableTaskIDs.contains(task.id))
      .help("Reopen")
    } else {
      Button {
        library.complete(task.id)
      } label: {
        Image(systemName: "circle")
      }
      .buttonStyle(.plain)
      .help("Complete")
    }
  }

  @ViewBuilder
  private var menu: some View {
    if isCompleted {
      if library.reopenableTaskIDs.contains(task.id) {
        Button("Reopen") { library.reopen(task.id) }
      }
    } else {
      ItemFieldMenuItems(library: library, taskID: task.id)
      Button("Add Tasks") { library.addTasks(to: task.id) }
    }
    Divider()
    Button("Delete Permanently…", role: .destructive) { confirmingDelete = true }
  }
}

/// The menu items a task and a project share, as both are the same kind of item: priority, estimate, repeat,
/// duplicate and tags.
private struct ItemFieldMenuItems: View {
  let library: LibraryViewModel
  let taskID: TaskID

  /// Estimates offered in the menu, in minutes.
  private static let estimateChoices = [5, 15, 30, 60]

  var body: some View {
    Menu("Priority") {
      ForEach(Priority.allCases, id: \.self) { priority in
        Button(priority.title, systemImage: priority.symbol) { library.prioritize(taskID, as: priority) }
      }
      Divider()
      Button("None") { library.prioritize(taskID, as: nil) }
    }
    Menu("Estimate") {
      ForEach(Self.estimateChoices, id: \.self) { minutes in
        Button("\(minutes)m") { library.estimate(taskID, as: minutes) }
      }
      Divider()
      Button("None") { library.estimate(taskID, as: nil) }
    }
    RepeatMenuItems(library: library, taskID: taskID)
    Button("Duplicate") { library.duplicate(taskID) }
    Button("Move Up") { library.moveUp(taskID) }
    Button("Move Down") { library.moveDown(taskID) }
    Menu("Tags") {
      ForEach(library.tags) { item in
        Button {
          library.toggleTag(item.id, on: taskID)
        } label: {
          if library.tagItems(of: taskID).contains(where: { $0.id == item.id }) {
            Label(item.name, systemImage: "checkmark")
          } else {
            Text(item.name)
          }
        }
      }
    }
    .disabled(library.tags.isEmpty)
  }
}

extension ProjectKind {
  /// The SF Symbol a project of this kind shows.
  var symbol: String {
    switch self {
    case .parallel: "list.bullet"
    case .sequential: "list.number"
    }
  }
}
