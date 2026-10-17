import LuthorDomain
import LuthorViewModels
import SwiftUI

/// Projects in Miller columns: the inbox and the top-level projects first, then one column for each
/// project on the way to the one shown, listing its sub-projects and tasks in the order they were added.
/// While the inbox is shown, its tasks are the last column. Tasks that are not next actions are dimmed.
/// Drag a task onto a project to file it, a project onto another to nest it, or onto a column to move it
/// into that column's project; the first column makes it top-level.
struct ColumnBrowserView: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 0) {
        ForEach(Array(library.columns.enumerated()), id: \.element.id) { position, column in
          ColumnView(library: library, column: column, position: position)
          Divider()
        }
        if library.sidebarSelection == .inbox {
          InboxColumnView(library: library)
          Divider()
        }
      }
    }
  }
}

/// What a click in a column picks.
private enum ColumnSelection: Hashable {
  case inbox
  case project(ProjectID)
  case task(TaskID)
}

/// One column: the inbox and top-level projects, or the children of one project.
private struct ColumnView: View {
  @Bindable var library: LibraryViewModel
  let column: ProjectColumn
  /// Where the column is among the columns; the first lists the top-level projects.
  let position: Int

  var body: some View {
    List(selection: selection) {
      if column.parentID == nil {
        Label("Inbox", systemImage: "tray")
          .tag(ColumnSelection.inbox)
      }
      ForEach(column.entries) { entry in
        switch entry {
        case .project(let project):
          ProjectRow(library: library, project: project)
            .tag(ColumnSelection.project(project.id))
        case .task(let task):
          TaskRow(task: task, isNextAction: library.nextActions.contains(task.id)) { library.complete(task.id) }
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
        if column.parentID == nil { return library.sidebarSelection == .inbox ? .inbox : nil }
        return library.selection.map(ColumnSelection.task)
      },
      set: { picked in
        switch picked {
        case .inbox:
          library.open(.inbox)
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

/// The last column while the inbox is shown: its tasks.
private struct InboxColumnView: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    List(selection: $library.selection) {
      ForEach(library.tasks, id: \.id) { task in
        TaskRow(task: task, isNextAction: library.nextActions.contains(task.id)) { library.complete(task.id) }
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

  var body: some View {
    HStack(spacing: 8) {
      Button(action: complete) {
        Image(systemName: "circle")
      }
      .buttonStyle(.plain)
      .help("Complete")
      Text(task.title)
        .foregroundStyle(isNextAction ? .primary : .secondary)
    }
    .draggable(task.id.rawValue)
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
