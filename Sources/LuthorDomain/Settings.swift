/// A day of the week, Monday first.
public enum Weekday: String, Sendable, CaseIterable, Codable, Hashable {
  case monday, tuesday, wednesday, thursday, friday, saturday, sunday

  /// The `SettingKey` its capacity is stored under.
  public var capacityKey: SettingKey {
    switch self {
    case .monday: .capacityMonday
    case .tuesday: .capacityTuesday
    case .wednesday: .capacityWednesday
    case .thursday: .capacityThursday
    case .friday: .capacityFriday
    case .saturday: .capacitySaturday
    case .sunday: .capacitySunday
    }
  }

  /// Minutes the weekday carries before any `SettingChanged` touches it: a working day, none at the
  /// weekend.
  public var builtInCapacityMinutes: Int {
    switch self {
    case .saturday, .sunday: 0
    case .monday, .tuesday, .wednesday, .thursday, .friday: 480
    }
  }
}

/// One configurable value a view, or the whole library, plans with. The log carries only changes
/// (`SettingChanged`); `Settings` is what the domain resolves them to. A key `apply(_:)` does not
/// recognise is ignored, so an old build survives a newer log.
public enum SettingKey: String, Codable, Sendable, CaseIterable, Hashable {
  /// Minutes an unestimated task counts as.
  case defaultEstimateMinutes
  /// Percentage of a day's capacity held back as a buffer, never planned into.
  case bufferPercentage
  case capacityMonday
  case capacityTuesday
  case capacityWednesday
  case capacityThursday
  case capacityFriday
  case capacitySaturday
  case capacitySunday
  /// The view `luthor add` and imports use when none is named. Global only; a view cannot override
  /// which view is the default.
  case defaultViewID
}

/// The planning numbers a view resolves to: its own overrides, then the global values, then the
/// built-in defaults. Never stored itself; computed by `LibraryState` from `SettingChanged` events on
/// replay.
public struct Settings: Equatable, Sendable {
  public static let defaultEstimateMinutes = 5
  public static let defaultBufferPercentage = 40

  public let defaultEstimateMinutes: Int
  public let bufferPercentage: Int
  /// Usable minutes for each weekday, before the buffer.
  public let capacity: [Weekday: Int]

  public init(defaultEstimateMinutes: Int, bufferPercentage: Int, capacity: [Weekday: Int]) {
    self.defaultEstimateMinutes = defaultEstimateMinutes
    self.bufferPercentage = bufferPercentage
    self.capacity = capacity
  }
}
