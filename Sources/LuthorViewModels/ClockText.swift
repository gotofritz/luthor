import Foundation

/// A time of day, given in minutes after midnight, as `09:00`; past midnight it starts again, so
/// 25:00 is `01:00`.
public func clockText(_ minutes: Int) -> String {
  let hours = minutes / 60 % 24
  let rest = minutes % 60
  return (hours < 10 ? "0" : "") + "\(hours):" + (rest < 10 ? "0" : "") + "\(rest)"
}
