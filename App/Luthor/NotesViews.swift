import Foundation
import LuthorViewModels
import SwiftUI

/// Plain-text notes with their web addresses made clickable, or "No notes".
struct NotesView: View {
  let notes: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Notes")
        .font(.headline)
      if let notes {
        Text(Self.linkified(notes))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Text("No notes")
          .foregroundStyle(.secondary)
      }
    }
  }

  /// The notes with each web address a link.
  static func linkified(_ notes: String) -> AttributedString {
    var text = AttributedString(notes)
    for link in NoteLinks.links(in: notes) {
      guard let range = Range(link.range, in: text) else { continue }
      text[range].link = link.url
    }
    return text
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
