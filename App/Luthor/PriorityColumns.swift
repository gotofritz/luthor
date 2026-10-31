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
          .selectionBackground(library.selectedPriorities.contains(priority))
      }
    }
    .accentSelectionOnly()
    .resizableColumn(library, id: "priorities", usually: 200)
  }
}

/// The tasks of the priorities picked as one list under one header, its due dates in place of the priority,
/// ended by a row of plus buttons, one for each priority picked, that add a task with that priority.
struct PriorityListsColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    List(selection: Binding(get: { library.selectedIDs }, set: { library.setSelection($0) })) {
      // The priorities are named in the column to the left, where the ones listed are picked.
      ListSortHeader(library: library, listID: LibraryViewModel.prioritiesListID, isRow: true)
        .listRowSeparator(.hidden)
      ForEach(library.priorityList, id: \.id) { task in
        TaskRow(library: library, task: task, listID: LibraryViewModel.prioritiesListID)
          .tag(task.id)
      }
      if let item = library.newItem, item.parentID == nil {
        NewItemRow(item: item)
      }
      HStack {
        ForEach(library.priorityGroups) { group in
          Button {
            library.addTask(withPriority: group.priority)
          } label: {
            Image(systemName: "plus")
          }
          .buttonStyle(.borderless)
          .help("Add a task with priority \(group.priority?.title ?? "none")")
          .accessibilityLabel("Add \(group.priority?.title ?? "no priority")")
        }
      }
    }
    .accentSelectionOnly()
    .resizableColumn(library, id: LibraryViewModel.prioritiesListID, usually: 440) {
      library.widestTitle(inColumn: LibraryViewModel.prioritiesListID).map {
        library.fittedWidth(forTitleWidth: titleWidth($0), inList: LibraryViewModel.prioritiesListID)
      }
    }
  }
}
