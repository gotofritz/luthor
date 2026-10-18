/// Notes seen as bullet points: one for each non-blank line of the notes text. The notes stay one plain
/// text, so no event changes.
public enum NoteBullets {
  /// The non-blank lines of `notes`, each without surrounding whitespace; none for no notes.
  public static func bullets(in notes: String?) -> [String] {
    (notes ?? "").split(whereSeparator: \.isNewline).map { Commands.trimmed(String($0)) }.filter { !$0.isEmpty }
  }

  /// The notes text that has these bullets, one to a line.
  public static func notes(from bullets: [String]) -> String {
    bullets.joined(separator: "\n")
  }
}
