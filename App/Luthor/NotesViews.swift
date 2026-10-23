import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The notes of a card: a bullet for each line (drawn by `LinkedText`), web addresses made clickable, each with a button that
/// deletes it, and a click on one turns it into a field; below them a field adds a note. A card that cannot be changed
/// (`canAdd` false) shows the bullets alone.
struct CardNotesView: View {
  let library: LibraryViewModel
  let itemID: TaskID
  let notes: String?
  let canAdd: Bool
  @State private var draft = ""
  @State private var editing: Int?
  @State private var editText = ""
  @FocusState private var isEditing: Bool

  private var bullets: [String] {
    NoteBullets.bullets(in: notes)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Notes")
        .font(Theme.section)
      if bullets.isEmpty && !canAdd {
        Text("No notes")
          .foregroundStyle(.secondary)
      }
      ForEach(Array(bullets.enumerated()), id: \.offset) { position, bullet in
        HStack(alignment: .top, spacing: 6) {
          if canAdd && editing == position {
            TextField("Note", text: $editText, axis: .vertical)
              .textFieldStyle(.roundedBorder)
              .lineLimit(1...5)
              .focused($isEditing)
              .onSubmit { finishEditing(position) }
              .onChange(of: isEditing) { if !isEditing { finishEditing(position) } }
          } else {
            LinkedText(text: bullet)
              .frame(maxWidth: .infinity, alignment: .leading)
              .onTapGesture { if canAdd { startEditing(position, bullet) } }
          }
          if canAdd {
            Button {
              library.deleteNote(at: position, of: itemID)
            } label: {
              Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Delete this note")
            .accessibilityLabel("Delete note")
          }
        }
      }
      if canAdd {
        TextField("Add a note", text: $draft, axis: .vertical)
          .textFieldStyle(.roundedBorder)
          .lineLimit(1...5)
          .onSubmit(add)
      }
    }
  }

  /// A click on a note turns it into a field holding its text.
  private func startEditing(_ position: Int, _ bullet: String) {
    editText = bullet
    editing = position
    isEditing = true
  }

  /// Return, or a click elsewhere, keeps the text; a blank one deletes the note.
  private func finishEditing(_ position: Int) {
    guard editing == position else { return }
    editing = nil
    library.editNote(at: position, of: itemID, to: editText)
  }

  private func add() {
    library.appendNote(draft, to: itemID)
    draft = ""
  }
}

/// The notes of a card in edit mode: a text editor that is open from the start, with no Edit of its own.
struct NotesEditor: View {
  @Binding var notes: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Notes")
        .font(Theme.section)
      TextEditor(text: $notes)
        .font(.body)
        .frame(minHeight: 120)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.4)))
    }
  }
}
