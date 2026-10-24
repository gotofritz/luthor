import Foundation

/// The minutes since midnight by the system clock.
public func minutesSinceMidnight() -> Int {
  let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
  return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
}

/// A time of day, given in minutes after midnight, as `09:00`.
public func clockText(_ minutes: Int) -> String {
  let hours = minutes / 60
  let rest = minutes % 60
  return (hours < 10 ? "0" : "") + "\(hours):" + (rest < 10 ? "0" : "") + "\(rest)"
}
