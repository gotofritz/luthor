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
  /// Scrolls the column fully into view; called on every click in it.
  let reveal: () -> Void

  var body: some View {
    List(selection: selection) {
      if let project = headProject {
        Label(project.title, systemImage: project.kind.symbol)
          .font(.headline)
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

/// What the plus button at the end of a column can add.
private enum NewItem: Hashable {
  case task
  case project(ProjectKind)

  var symbol: String {
    switch self {
    case .task: "circle"
    case .project(let kind): kind.symbol
    }
  }

  var title: String {
    switch self {
    case .task: "Task"
    case .project(.parallel): "Parallel project"
    case .project(.sequential): "Sequential project"
    }
  }
}

/// The plus button at the end of a column. It opens a field that adds a task or a project, as picked beside it,
/// to the project the column lists; the first column lists top-level projects and adds only those. Return adds and
/// keeps the field open for the next one, Escape closes it.
private struct AddItemRow: View {
  let library: LibraryViewModel
  /// The project the column lists; `nil` for the first column.
  let parentID: TaskID?
  @State private var isAdding = false
  @State private var title = ""
  @State private var kind: NewItem
  @FocusState private var focused: Bool

  init(library: LibraryViewModel, parentID: TaskID?) {
    self.library = library
    self.parentID = parentID
    _kind = State(initialValue: parentID == nil ? .project(.parallel) : .task)
  }

  private var choices: [NewItem] {
    (parentID == nil ? [] : [NewItem.task]) + [.project(.parallel), .project(.sequential)]
  }

  var body: some View {
    if isAdding {
      VStack(alignment: .leading, spacing: 6) {
        TextField("New \(kind.title.lowercased())", text: $title)
          .textFieldStyle(.roundedBorder)
          .focused($focused)
          .onAppear { focused = true }
          .onSubmit(add)
          .onExitCommand { isAdding = false }
        Picker("Add", selection: $kind) {
          ForEach(choices, id: \.self) { choice in
            Image(systemName: choice.symbol).help(choice.title).tag(choice)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }
    } else {
      Button {
        isAdding = true
      } label: {
        Image(systemName: "plus")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.borderless)
      .help(parentID == nil ? "Add a project" : "Add a task or a project")
      .accessibilityLabel("Add")
    }
  }

  private func add() {
    switch kind {
    case .task: library.addTask(titled: title, to: parentID)
    case .project(let projectKind): library.addProject(titled: title, kind: projectKind, under: parentID)
    }
    if library.errorMessage == nil { title = "" }
  }
}
