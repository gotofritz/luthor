import Foundation

/// The estimate slider: a logarithmic scale from 5 minutes at one end to a week at the other, so short
/// estimates have room and long ones are still reachable. Any estimate in between can be picked, to a step
/// that grows with its size (a minute, five, fifteen, then an hour).
public enum EstimateScale {
  public static let shortest = 5
  public static let longest = 10_080

  /// The estimate in minutes at `position`, 0 for the left end of the slider to 1 for the right end.
  public static func minutes(at position: Double) -> Int {
    let clamped = min(max(position, 0), 1)
    let raw = Double(shortest) * pow(Double(longest) / Double(shortest), clamped)
    let step = step(at: raw)
    let snapped = Int((raw / Double(step)).rounded()) * step
    return min(max(snapped, shortest), longest)
  }

  /// The position of the slider for an estimate, held to its ends.
  public static func position(of minutes: Int) -> Double {
    let clamped = Double(min(max(minutes, shortest), longest))
    return log(clamped / Double(shortest)) / log(Double(longest) / Double(shortest))
  }

  /// An estimate as the card shows it: "45m", "2h 30m", "1d 4h", "1w".
  public static func label(_ minutes: Int) -> String {
    let units = [("w", 10_080), ("d", 1_440), ("h", 60), ("m", 1)]
    guard let first = units.first(where: { minutes >= $0.1 }) else { return "\(minutes)m" }
    let whole = minutes / first.1
    let rest = minutes % first.1
    guard rest > 0, let next = units.first(where: { $0.1 < first.1 && rest >= $0.1 }) else {
      return "\(whole)\(first.0)"
    }
    return "\(whole)\(first.0) \(rest / next.1)\(next.0)"
  }

  private static func step(at minutes: Double) -> Int {
    switch minutes {
    case ..<30: 1
    case ..<120: 5
    case ..<1_440: 15
    default: 60
    }
  }
}
