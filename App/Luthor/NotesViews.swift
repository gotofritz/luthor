import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The notes of a read-only card: a bullet for each line, web addresses made clickable, each with a button that
/// deletes it, and below them a field that adds a note without opening the editor. A card that cannot be changed
/// (`canAdd` false) shows the bullets alone.
struct CardNotesView: View {
  let library: LibraryViewModel
  let itemID: TaskID
  let notes: String?
  let canAdd: Bool
  @State private var draft = ""

  private var bullets: [String] {
    NoteBullets.bullets(in: notes)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Notes")
        .font(.headline)
      if bullets.isEmpty && !canAdd {
        Text("No notes")
          .foregroundStyle(.secondary)
      }
      ForEach(Array(bullets.enumerated()), id: \.offset) { position, bullet in
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text("•")
          Text(Self.linkified(bullet))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
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

  private func add() {
    library.appendNote(draft, to: itemID)
    draft = ""
  }

  /// The text with each web address a link.
  static func linkified(_ text: String) -> AttributedString {
    var linked = AttributedString(text)
    for link in NoteLinks.links(in: text) {
      guard let range = Range(link.range, in: linked) else { continue }
      linked[range].link = link.url
    }
    return linked
  }
}

/// The notes of a card in edit mode: a text editor that is open from the start, with no Edit of its own.
struct NotesEditor: View {
  @Binding var notes: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Notes")
        .font(.headline)
      TextEditor(text: $notes)
        .font(.body)
        .frame(minHeight: 120)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.4)))
    }
  }
}
