/// The quick-capture syntax shared by the CLI and the app: `call bank !a 15m` captures "call bank" with
/// priority A and a 15-minute estimate. Pure, so both sides parse the same way.
public enum QuickCapture {
  /// What one piece of captured text means: the title with its tags stripped, and whichever tags it had.
  public struct Parsed: Equatable, Sendable {
    public let title: String
    /// The priority named by a `!a`, `!b`, `!c` or `!someday` tag; `nil` if none is present.
    public let priority: Priority?
    /// The minutes named by an `<n>m` tag; `nil` if none is present.
    public let estimateMinutes: Int?
  }

  /// Splits `!a`, `!b`, `!c`, `!someday` (a priority) and `<n>m` (an estimate in minutes) out of `input`,
  /// in any order and case; the title is the words left over, in their original order. Each tag keeps its
  /// last occurrence; either, both or neither may be present.
  public static func parse(_ input: String) -> Parsed {
    var priority: Priority?
    var estimateMinutes: Int?
    let title =
      input.split(whereSeparator: \.isWhitespace)
      .filter { word in
        if let tagged = Self.priority(word) {
          priority = tagged
          return false
        }
        if let minutes = Self.minutes(word) {
          estimateMinutes = minutes
          return false
        }
        return true
      }
      .joined(separator: " ")
    return Parsed(title: title, priority: priority, estimateMinutes: estimateMinutes)
  }

  private static func priority(_ word: Substring) -> Priority? {
    guard word.hasPrefix("!") else { return nil }
    switch word.dropFirst().lowercased() {
    case "a": return .critical
    case "b": return .important
    case "c": return .optional
    case "someday": return .someday
    default: return nil
    }
  }

  private static func minutes(_ word: Substring) -> Int? {
    guard word.count > 1, word.hasSuffix("m"), let value = Int(word.dropLast()), value > 0 else { return nil }
    return value
  }
}
