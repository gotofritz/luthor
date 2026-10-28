import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The priorities and, last, no priority. A plain list selection: a click picks one, a shift-click a range
/// and a command-click adds a priority to the picked ones or drops it.
struct PriorityColumn: View {
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

/// The tasks of the priorities picked, a list for each, with its due dates in place of the priority and ended by
/// a plus button that adds a task with that priority.
struct PriorityListsColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    List(selection: $library.selection) {
      ForEach(library.priorityGroups) { group in
        Section(group.priority?.title ?? "No priority") {
          ForEach(group.tasks, id: \.id) { task in
            TaskRow(library: library, task: task, showsPriority: false, showsDate: true)
              .tag(task.id)
          }
          if let item = library.newItem, item.parentID == nil, item.card.priority == group.priority {
            NewItemRow(item: item)
          }
          Button {
            library.addTask(withPriority: group.priority)
          } label: {
            Image(systemName: "plus")
              .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.borderless)
          .help("Add a task with this priority")
          .accessibilityLabel("Add")
        }
      }
    }
    .frame(width: 320)
  }
}
