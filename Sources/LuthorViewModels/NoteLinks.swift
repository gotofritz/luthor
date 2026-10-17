import Foundation

/// A web address found in a note.
public struct NoteLink: Equatable, Sendable {
  /// Where the address is in the note.
  public let range: Range<String.Index>
  public let url: URL
}

/// Finds the web addresses in plain-text notes, so a card can make them clickable. An address starts with
/// `http://`, `https://` or `www.` and runs to the next whitespace, less the punctuation that ends a
/// sentence.
public enum NoteLinks {
  private static let opening: Set<Character> = ["(", "[", "<", "\"", "'"]
  private static let closing: [Character: Character] = [")": "(", "]": "[", ">": "<", "\"": "\"", "'": "'"]
  private static let sentenceEnd: Set<Character> = [".", ",", ";", ":", "!", "?"]

  /// The web addresses in `notes`, in order. An address without a scheme gets `http`.
  public static func links(in notes: String) -> [NoteLink] {
    var links: [NoteLink] = []
    var start = notes.startIndex
    while start < notes.endIndex {
      guard !notes[start].isWhitespace else {
        start = notes.index(after: start)
        continue
      }
      let end = notes[start...].firstIndex { $0.isWhitespace } ?? notes.endIndex
      if let link = link(in: notes, from: start, to: end) { links.append(link) }
      start = end
    }
    return links
  }

  /// The address in the word `notes[start..<end]`, if it is one.
  private static func link(in notes: String, from start: String.Index, to end: String.Index) -> NoteLink? {
    var first = start
    while first < end, opening.contains(notes[first]) { first = notes.index(after: first) }
    var last = end
    while last > first {
      let before = notes.index(before: last)
      let character = notes[before]
      let unmatched = closing[character].map { !notes[first..<before].contains($0) } ?? false
      guard sentenceEnd.contains(character) || unmatched else { break }
      last = before
    }
    let text = String(notes[first..<last])
    let lowered = text.lowercased()
    let hasScheme = lowered.hasPrefix("http://") || lowered.hasPrefix("https://")
    guard hasScheme || lowered.hasPrefix("www."), text.count > (hasScheme ? 8 : 4) else { return nil }
    guard let url = URL(string: hasScheme ? text : "http://" + text) else { return nil }
    return NoteLink(range: first..<last, url: url)
  }
}
