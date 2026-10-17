import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The Miller columns of the place the navigation rail has picked. The inbox is a list of its tasks. Today
/// is the plan of a day, its candidates and the tasks waited for. The projects are the top-level projects
/// first, then one column for each project on the way to the one shown, listing its sub-projects and tasks
/// in the order they were added. The priorities are the four priorities and no priority, picked like the rows of any
/// list, then the tasks that have one of the picked. Tasks that are not next actions are dimmed. Drag a task onto a
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

/// The tasks of the inbox, or of the priorities picked.
private struct TaskListColumn: View {
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
        .foregroundStyle(isCompleted ? .secondary : .primary)
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
