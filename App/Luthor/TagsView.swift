import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The Tags place's first column: the view's tags, each with how many open tasks carry it. A click picks one,
/// and the next column lists its tasks. Tags are made on a task's card, so this list has no capture field.
struct TagColumn: View {
  @Bindable var library: LibraryViewModel

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
      }
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

/// The tags of a task as the lists and the read-only card show them: `@calls @home`; `nil` for a task with none.
func tagLine(of tags: [TagItem]) -> String? {
  tags.isEmpty ? nil : tags.map { "@\($0.name)" }.joined(separator: " ")
}
