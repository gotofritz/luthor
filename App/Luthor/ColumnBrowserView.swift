import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The Miller columns of the place the navigation rail has picked. The inbox is a list of its tasks. Today
/// is the plan of a day, its candidates and the tasks waited for. The calendar is a list of days and the tasks
/// of the one picked. Review is the day looked back on. The weekly review is the projects due for review, the one
/// picked with its card, and its tasks. The
/// projects are the top-level projects first, then one column for each project on the way to the one shown, listing its sub-projects and tasks
/// in the order they were added. The priorities are the four priorities and no priority, picked like the rows of any
/// list, then the tasks that have one of the picked. The tags are the view's tags, then the tasks that carry the
/// one picked. Tasks that are not next actions are dimmed. Drag a task onto a
/// project to file it, a project onto another to nest it, or onto a column to move it into that column's
/// project; the first column makes it top-level.
struct ColumnBrowserView: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 0) {
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
            ColumnView(library: library, column: column, position: position)
            Divider()
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
        if library.section != .settings, let task = library.selectedTask {
          TaskCardColumn(library: library, task: task)
          Divider()
        }
      }
    }
  }
}

/// What a click in a column picks.
private enum ColumnSelection: Hashable {
  case project(ProjectID)
  case task(TaskID)
}

/// One column: the top-level projects, or the children of one project.
private struct ColumnView: View {
  @Bindable var library: LibraryViewModel
  let column: ProjectColumn
  /// Where the column is among the columns; the first lists the top-level projects.
  let position: Int

  var body: some View {
    VStack(spacing: 0) {
      if let project = library.shownProject, project.id == column.parentID {
        ProjectCard(library: library, project: project)
        Divider()
      }
      list
    }
    .frame(width: 260)
    .dropDestination(for: String.self) { payloads, _ in
      library.drop(payloads, on: column.parentID)
    }
  }

  private var list: some View {
    List(selection: selection) {
      ForEach(column.entries) { entry in
        switch entry {
        case .project(let project):
          ProjectRow(library: library, project: project)
            .tag(ColumnSelection.project(project.id))
        case .task(let task):
          TaskRow(library: library, task: task)
            .tag(ColumnSelection.task(task.id))
        }
      }
    }
  }

  /// The project of the path this column leads to, or the selected task of the project shown.
  private var selection: Binding<ColumnSelection?> {
    Binding(
      get: {
        if position < library.path.count { return .project(library.path[position]) }
        if column.parentID == nil { return nil }
        return library.selection.map(ColumnSelection.task)
      },
      set: { picked in
        switch picked {
        case .project(let projectID):
          library.open(.project(projectID))
        case .task(let taskID):
          if let parentID = column.parentID, library.path.last != parentID { library.open(.project(parentID)) }
          library.selection = taskID
        case nil:
          break
        }
      }
    )
  }
}

/// The priorities and, last, no priority. A plain list selection: a click picks one, a shift-click a range
/// and a command-click adds a priority to the picked ones or drops it.
private struct PriorityColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    List(
      selection: Binding(
        get: { library.selectedPriorities },
        set: { library.selectPriorities($0) }
      )
    ) {
      ForEach(LibraryViewModel.priorityRows, id: \.self) { priority in
        Label(priority?.title ?? "No priority", systemImage: priority?.symbol ?? "circle.dashed")
          .tag(priority)
      }
    }
    .frame(width: 200)
  }
}

/// The tasks of the inbox, of the priorities picked, of the tag picked, or of the project the weekly review
/// picked.
struct TaskListColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    List(selection: $library.selection) {
      ForEach(library.tasks, id: \.id) { task in
        TaskRow(library: library, task: task)
          .tag(task.id)
      }
    }
    .frame(width: 320)
  }
}

private struct ProjectRow: View {
  @Bindable var library: LibraryViewModel
  let project: Project

  private var isCompleted: Bool {
    library.completedProjectIDs.contains(project.id)
  }

  var body: some View {
    HStack {
      Label(project.title, systemImage: project.kind.symbol)
        .strikethrough(isCompleted)
        .foregroundStyle(isCompleted || project.status != .active ? .secondary : .primary)
      if project.status != .active {
        Image(systemName: project.status.symbol)
          .foregroundStyle(.secondary)
          .help(project.status.title)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .foregroundStyle(.secondary)
    }
    .draggable(LibraryViewModel.dragPayload(for: project.id))
    .dropDestination(for: String.self) { payloads, _ in
      library.drop(payloads, on: project.id)
    }
    .contextMenu {
      if isCompleted {
        if library.reopenableProjectIDs.contains(project.id) {
          Button("Reopen Project") { library.reopenProject(project.id) }
        }
      } else {
        Button("Complete Project") { library.completeProject(project.id) }
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
    }
  }
}

private struct TaskRow: View {
  @Bindable var library: LibraryViewModel
  let task: TaskItem

  /// Estimates offered on the context and Task menus, in minutes.
  static let estimateChoices = [5, 15, 30, 60]

  private var isCompleted: Bool {
    library.completedTaskIDs.contains(task.id)
  }

  private var isNextAction: Bool {
    library.nextActions.contains(task.id)
  }

  var body: some View {
    HStack(spacing: 8) {
      checkbox
      Text(task.title)
        .strikethrough(isCompleted)
        .foregroundStyle(isNextAction && !isCompleted ? .primary : .secondary)
      if let tags = tagLine(of: library.tagItems(of: task.id)) {
        Text(tags)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      if let estimate = task.estimate {
        Text("\(estimate)m")
          .foregroundStyle(.secondary)
          .help("Estimate")
      }
      if let priority = task.priority {
        Image(systemName: priority.symbol)
          .foregroundStyle(.secondary)
          .help(priority.title)
      }
    }
    .draggable(task.id.rawValue)
    .contextMenu { menu }
  }

  /// Completes the task; on a completed task that can be reopened, reopens it.
  @ViewBuilder
  private var checkbox: some View {
    if isCompleted {
      Button {
        library.reopen(task.id)
      } label: {
        Image(systemName: "checkmark.circle.fill")
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
      Menu("Priority") {
        ForEach(Priority.allCases, id: \.self) { priority in
          Button(priority.title, systemImage: priority.symbol) { library.prioritize(task.id, as: priority) }
        }
        Divider()
        Button("None") { library.prioritize(task.id, as: nil) }
      }
      Menu("Estimate") {
        ForEach(Self.estimateChoices, id: \.self) { minutes in
          Button("\(minutes)m") { library.estimate(task.id, as: minutes) }
        }
        Divider()
        Button("None") { library.estimate(task.id, as: nil) }
      }
      RepeatMenuItems(library: library, taskID: task.id)
      Menu("Tags") {
        ForEach(library.tags) { item in
          Button {
            library.toggleTag(item.id, on: task.id)
          } label: {
            if library.tagItems(of: task.id).contains(where: { $0.id == item.id }) {
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
