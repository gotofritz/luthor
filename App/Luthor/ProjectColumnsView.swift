import LuthorDomain
import LuthorViewModels
import SwiftUI

/// What a click in a column picks.
private enum ColumnSelection: Hashable {
  case project(TaskID)
  case task(TaskID)
  /// The first row of a project's column, the project itself, which picks its card.
  case header
}

/// One column: the top-level projects, or the project at its head followed by its children, and a plus button
/// at its end.
struct ColumnView: View {
  @Bindable var library: LibraryViewModel
  let column: ProjectColumn
  /// Where the column is among the columns; the first lists the top-level projects.
  let position: Int
  /// Scrolls the column to the left edge, as Finder does; called on every click in it.
  let reveal: () -> Void

  var body: some View {
    List(selection: selection) {
      if let project = headProject {
        Label(project.title, systemImage: "arrowtriangle.down.fill")
          .font(Theme.section)
          .tag(ColumnSelection.header)
          .contentShape(Rectangle())
          .onTapGesture { click(.header) }
          .help("Show the card of this project")
      }
      ForEach(column.entries) { entry in
        switch entry {
        case .project(let project):
          ProjectRow(library: library, project: project)
            .tag(ColumnSelection.project(project.id))
            .contentShape(Rectangle())
            .onTapGesture { click(.project(project.id)) }
            .dropDestination(for: String.self) { payloads, _ in
              library.drop(payloads, on: project.id)
            }
        case .task(let task):
          TaskRow(library: library, task: task)
            .tag(ColumnSelection.task(task.id))
            .contentShape(Rectangle())
            .onTapGesture { click(.task(task.id)) }
        }
      }
      AddItemRow(library: library, parentID: column.parentID)
    }
    .frame(width: 260)
    .dropDestination(for: String.self) { payloads, _ in
      library.drop(payloads, on: column.parentID)
    }
  }

  /// The project the column lists the children of; the first column has none.
  private var headProject: Project? {
    column.parentID.flatMap { id in library.knownProjects.first { $0.id == id } }
  }

  /// The project of the path this column leads to, else the task picked or, with none, the project at its head.
  private var selection: Binding<ColumnSelection?> {
    Binding(
      get: {
        if position < library.path.count { return .project(library.path[position]) }
        if column.parentID == nil { return nil }
        return library.selection.map(ColumnSelection.task) ?? .header
      },
      set: { picked in
        if let picked {
          choose(picked)
        } else {
          library.deselectColumn(of: column.parentID)
        }
      }
    )
  }

  /// A click. The list reports a change of its selection only, so a click on what is picked already, as the
  /// project whose column is open to the right, would do nothing; this one still closes what is picked beyond it.
  private func click(_ picked: ColumnSelection) {
    choose(picked)
    reveal()
  }

  private func choose(_ picked: ColumnSelection) {
    switch picked {
    case .project(let projectID):
      library.open(.project(projectID))
    case .header:
      if let parentID = column.parentID { library.open(.project(parentID)) }
    case .task(let taskID):
      if let parentID = column.parentID, library.path.last != parentID { library.open(.project(parentID)) }
      library.selection = taskID
    }
  }
}

/// The plus button at the end of a column. It starts a new item in the project the column lists, a task or
/// a project (the first column lists top-level projects and starts only those); the card in the next column
/// edits it, and the row above the button shows its title as it is typed.
private struct AddItemRow: View {
  let library: LibraryViewModel
  /// The project the column lists; `nil` for the first column.
  let parentID: TaskID?

  var body: some View {
    if let item = library.newItem, item.parentID == parentID {
      NewItemRow(item: item)
    }
    Button {
      library.beginNewItem(under: parentID, kind: parentID == nil ? .project(.parallel) : .task)
    } label: {
      Image(systemName: "plus")
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.borderless)
    .help(parentID == nil ? "Add a project" : "Add a task or a project")
    .accessibilityLabel("Add")
  }
}

/// The item being added, in the column it will land in: a box that shows the title as it is typed on the
/// card, and cannot be typed in.
private struct NewItemRow: View {
  let item: NewItemDraft

  var body: some View {
    let title = item.card.title
    Label(title.isEmpty ? "New \(item.kind.name)" : title, systemImage: item.kind.symbol)
      .foregroundStyle(title.isEmpty ? .secondary : .primary)
      .padding(6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.5)))
      .accessibilityLabel("New item: \(title)")
  }
}

extension NewItemKind {
  /// The SF Symbol of the kind: a task's circle, or its project's.
  var symbol: String {
    switch self {
    case .task: "circle"
    case .project(let kind): kind.symbol
    }
  }

  /// What the kind is called, in lower case.
  var name: String {
    switch self {
    case .task: "task"
    case .project(.parallel): "parallel project"
    case .project(.sequential): "sequential project"
    }
  }
}
