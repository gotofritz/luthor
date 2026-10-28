import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The Tags place's first column: the view's tags, each with how many open tasks carry it. A click picks one,
/// and the next column lists its tasks. Tags are made on a task's card, so this list has no capture field.
struct TagColumn: View {
  @Bindable var library: LibraryViewModel
  /// The tag whose removal is waiting for a yes: one that tasks carry.
  @State private var removing: TagItem?

  var body: some View {
    List(selection: Binding(get: { library.selectedTagID }, set: { library.showTag($0) })) {
      ForEach(library.tags) { item in
        HStack {
          Label(item.name, systemImage: "tag")
          Spacer()
          Text("\(library.tagTaskCounts[item.id] ?? 0)")
            .foregroundStyle(.secondary)
        }
        .tag(item.id)
        .contextMenu {
          Button("Remove Tag", role: .destructive) { remove(item) }
        }
      }
    }
    .confirmationDialog(
      "Remove “@\(removing?.name ?? "")”?",
      isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
      presenting: removing
    ) { item in
      Button("Remove", role: .destructive) { library.removeTag(item.id) }
    } message: { item in
      let count = library.tagUseCount(item.id)
      Text("It is taken off \(count == 1 ? "1 task" : "\(count) tasks").")
    }
    .overlay {
      if library.tags.isEmpty {
        Text("No tags yet. Add one on a task's card.")
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding()
      }
    }
    .frame(width: 220)
  }
}

extension TagColumn {
  /// Removes a tag nothing carries at once; asks first about one that tasks carry.
  private func remove(_ item: TagItem) {
    if library.tagUseCount(item.id) == 0 {
      library.removeTag(item.id)
    } else {
      removing = item
    }
  }
}

/// The tags of a task as the lists and the read-only card show them: `@calls @home`; `nil` for a task with none.
func tagLine(of tags: [TagItem]) -> String? {
  tags.isEmpty ? nil : tags.map { "@\($0.name)" }.joined(separator: " ")
}
