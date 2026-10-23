import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The pulldown at the top of a card that says which project the task or project is in, as a tree of all the
/// projects of the view, and moves it when another is picked. The card shows up in places that list tasks of
/// every project (priorities, dates, tags), where nothing else tells which one it belongs to. A project cannot be
/// moved into itself or into anything inside it.
struct CardProjectPicker: View {
  @Bindable var library: LibraryViewModel
  let itemID: TaskID
  let parentID: TaskID?
  let isProject: Bool

  var body: some View {
    Picker(isProject ? "In" : "Project", selection: selection) {
      Text("No project").tag(TaskID?.none)
      ForEach(library.projectOutline(excludingSubtreeOf: isProject ? itemID : nil)) { entry in
        Text(String(repeating: "    ", count: entry.depth) + entry.title).tag(TaskID?.some(entry.id))
      }
    }
  }

  private var selection: Binding<TaskID?> {
    Binding(
      get: { parentID },
      set: { target in
        if isProject {
          library.nest(itemID, under: target)
        } else {
          library.file(itemID, into: target)
        }
      })
  }
}
