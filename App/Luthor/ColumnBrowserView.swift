import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The Miller columns of the place the navigation rail has picked. The inbox is a list of its tasks. The
/// projects are the top-level projects first, then one column for each project on the way to the one
/// shown, listing its sub-projects and tasks in the order they were added. The priorities are the four
/// priorities, which add up when clicked, then the tasks that have one of the picked. Tasks that are not
/// next actions are dimmed. Drag a task onto a project to file it, a project onto another to nest it, or
/// onto a column to move it into that column's project; the first column makes it top-level.
struct ColumnBrowserView: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 0) {
        switch library.section {
        case .inbox:
          TaskListColumn(library: library)
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
    List(selection: selection) {
      ForEach(column.entries) { entry in
        switch entry {
        case .project(let project):
          ProjectRow(library: library, project: project)
            .tag(ColumnSelection.project(project.id))
        case .task(let task):
          TaskRow(
            task: task, isNextAction: library.nextActions.contains(task.id),
            complete: { library.complete(task.id) }, setPriority: { library.prioritize(task.id, as: $0) },
            setEstimate: { library.estimate(task.id, as: $0) }
          )
          .tag(ColumnSelection.task(task.id))
        }
      }
    }
    .frame(width: 240)
    .dropDestination(for: String.self) { payloads, _ in
      library.drop(payloads, on: column.parentID)
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

/// The priorities, each picked or not by a click. Unlike a list selection, a click adds to the picked
/// priorities instead of replacing them, and clicking a picked one drops it.
private struct PriorityColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    List {
      ForEach(Priority.allCases, id: \.self) { priority in
        let picked = library.selectedPriorities.contains(priority)
        Label(priority.title, systemImage: priority.symbol)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 2)
          .padding(.horizontal, 6)
          .background(picked ? Color.accentColor.opacity(0.25) : .clear, in: .rect(cornerRadius: 5))
          .contentShape(.rect)
          .onTapGesture { library.togglePriority(priority) }
          .accessibilityAddTraits(picked ? .isSelected : [])
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
        TaskRow(
          task: task, isNextAction: library.nextActions.contains(task.id),
          complete: { library.complete(task.id) }, setPriority: { library.prioritize(task.id, as: $0) },
          setEstimate: { library.estimate(task.id, as: $0) }
        )
        .tag(task.id)
      }
    }
    .frame(width: 320)
  }
}

private struct ProjectRow: View {
  @Bindable var library: LibraryViewModel
  let project: Project

  var body: some View {
    HStack {
      Label(project.title, systemImage: project.kind.symbol)
      Spacer()
      Image(systemName: "chevron.right")
        .foregroundStyle(.secondary)
    }
    .draggable(LibraryViewModel.dragPayload(for: project.id))
    .dropDestination(for: String.self) { payloads, _ in
      library.drop(payloads, on: project.id)
    }
    .contextMenu {
      Button("Complete Project") { library.completeProject(project.id) }
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

private struct TaskRow: View {
  let task: TaskItem
  let isNextAction: Bool
  let complete: () -> Void
  let setPriority: (Priority?) -> Void
  let setEstimate: (Int?) -> Void

  /// Estimates offered on the context and Task menus, in minutes.
  static let estimateChoices = [5, 15, 30, 60]

  var body: some View {
    HStack(spacing: 8) {
      Button(action: complete) {
        Image(systemName: "circle")
      }
      .buttonStyle(.plain)
      .help("Complete")
      Text(task.title)
        .foregroundStyle(isNextAction ? .primary : .secondary)
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
    .contextMenu {
      Menu("Priority") {
        ForEach(Priority.allCases, id: \.self) { priority in
          Button(priority.title, systemImage: priority.symbol) { setPriority(priority) }
        }
        Divider()
        Button("None") { setPriority(nil) }
      }
      Menu("Estimate") {
        ForEach(Self.estimateChoices, id: \.self) { minutes in
          Button("\(minutes)m") { setEstimate(minutes) }
        }
        Divider()
        Button("None") { setEstimate(nil) }
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
