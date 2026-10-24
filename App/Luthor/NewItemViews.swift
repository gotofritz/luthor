import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The card of an item being added from the plus button of a column, in the column after it. It is in edit mode
/// from the start, with the title field focused; what is typed in the title shows in the column as it goes.
/// OK makes the item with the fields set, Cancel or Escape drops it.
struct NewItemCardColumn: View {
  @Bindable var library: LibraryViewModel
  let item: NewItemDraft

  @State private var fields: CardFields
  @State private var notes = ""
  @FocusState private var titleFocused: Bool

  init(library: LibraryViewModel, item: NewItemDraft) {
    self.library = library
    self.item = item
    _fields = State(initialValue: CardFields(priority: item.card.priority, estimate: item.card.estimate))
  }

  /// A task only where a project is being added to; the first column holds projects.
  private var kinds: [NewItemKind] {
    (item.parentID == nil ? [] : [NewItemKind.task]) + [.project(.parallel), .project(.sequential)]
  }

  private var title: Binding<String> {
    Binding(get: { library.newItem?.card.title ?? "" }, set: { library.setNewItemTitle($0) })
  }

  private var kind: Binding<NewItemKind> {
    Binding(get: { library.newItem?.kind ?? item.kind }, set: { library.setNewItemKind($0) })
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        TextField("Title", text: title, prompt: Text("New \(kind.wrappedValue.name)"))
          .textFieldStyle(.roundedBorder)
          .font(.title3)
          .focused($titleFocused)
          .onAppear { titleFocused = true }
          .onSubmit(save)
          .onExitCommand { library.cancelNewItem() }
        Picker("Kind", selection: kind) {
          ForEach(kinds, id: \.self) { choice in
            Image(systemName: choice.symbol).help(choice.name).tag(choice)
          }
        }
        .pickerStyle(.segmented)
        CardFieldsForm(library: library, fields: $fields, submit: save, canSchedule: kind.wrappedValue == .task)
          .onChange(of: fields.priority) { library.setNewItemPriority(fields.priority) }
          .onChange(of: fields.estimate) { library.setNewItemEstimate(fields.estimate) }
          .onChange(of: library.newItem?.card.priority) { _, priority in
            if let priority { fields.priority = priority }
          }
          .onChange(of: library.newItem?.card.estimate) { _, estimate in
            if let estimate { fields.estimate = estimate }
          }
        NotesEditor(notes: $notes)
        EditButtons(save: save) { library.cancelNewItem() }
      }
      .padding(12)
    }
    .frame(width: 300)
    .id(item.parentID?.rawValue ?? "top")
  }

  private func save() {
    library.saveNewItem(fields.draft(title: title.wrappedValue, notes: notes))
  }
}
