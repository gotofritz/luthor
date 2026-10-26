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

  /// The `SettingKey`s its start and end of day are stored under, in minutes after midnight.
  public var startKey: SettingKey {
    switch self {
    case .monday: .dayStartMonday
    case .tuesday: .dayStartTuesday
    case .wednesday: .dayStartWednesday
    case .thursday: .dayStartThursday
    case .friday: .dayStartFriday
    case .saturday: .dayStartSaturday
    case .sunday: .dayStartSunday
    }
  }

  public var endKey: SettingKey {
    switch self {
    case .monday: .dayEndMonday
    case .tuesday: .dayEndTuesday
    case .wednesday: .dayEndWednesday
    case .thursday: .dayEndThursday
    case .friday: .dayEndFriday
    case .saturday: .dayEndSaturday
    case .sunday: .dayEndSunday
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

/// When a day starts and ends, in minutes after midnight.
public struct DayHours: Equatable, Sendable {
  /// 09:00 to 17:00.
  public static let builtIn = DayHours(start: 9 * 60, end: 17 * 60)

  /// The latest minute any stretch may end at, 06:00 the next day: the day may run on past midnight up to the
  /// time it changes (a setting, at most 06:00), and these minutes still count as that day.
  public static let latest = 30 * 60

  public let start: Int
  public let end: Int

  public init(start: Int, end: Int) {
    self.start = start
    self.end = end
  }

  /// Whether it is a stretch within one day: it starts before it ends, and both fall on that day (or before
  /// the day changes, after midnight).
  public var isValid: Bool {
    start >= 0 && end <= Self.latest && start < end
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
  /// When each weekday starts and ends, in minutes after midnight.
  case dayStartMonday, dayStartTuesday, dayStartWednesday, dayStartThursday, dayStartFriday
  case dayStartSaturday, dayStartSunday
  case dayEndMonday, dayEndTuesday, dayEndWednesday, dayEndThursday, dayEndFriday, dayEndSaturday
  case dayEndSunday
  /// The default view; nothing reads it since the CLI was removed. Global only; a view cannot override
  /// which view is the default.
  case defaultViewID
  /// The `ThemeAccent` a view is drawn in, by its raw value; per view, so each view looks its own.
  case themeAccent
  /// The time after midnight at which one day changes into the next, in minutes after midnight; global.
  case dayChangesAt
}

/// The colours a view can take as its accent. Names only: which colour each one is lives in the app.
public enum ThemeAccent: String, Codable, Sendable, CaseIterable, Hashable {
  case navy, alpine, glacier, forest, plum, graphite, red, sunflower
}

/// The planning numbers a view resolves to: its own overrides, then the global values, then the
/// built-in defaults. Never stored itself; computed by `LibraryState` from `SettingChanged` events on
/// replay.
public struct Settings: Equatable, Sendable {
  public static let defaultEstimateMinutes = 5
  public static let defaultBufferPercentage = 40
  /// 04:00: a day lasts until then, so one that ends at 01:00 is not cut at midnight.
  public static let defaultDayChangesAt = 4 * 60
  /// The latest time the day may change at, 06:00.
  public static let latestDayChangesAt = 6 * 60

  public let defaultEstimateMinutes: Int
  public let bufferPercentage: Int
  /// Usable minutes for each weekday, before the buffer.
  public let capacity: [Weekday: Int]
  /// When each weekday starts and ends.
  public let dayHours: [Weekday: DayHours]
  /// The accent the view is drawn in.
  public let themeAccent: ThemeAccent
  /// When the day changes, in minutes after midnight.
  public let dayChangesAt: Int

  /// The last minute a day reaches, counted from its own midnight: the next midnight and the time the day
  /// changes.
  public var dayLimit: Int { 24 * 60 + dayChangesAt }

  public init(
    defaultEstimateMinutes: Int, bufferPercentage: Int, capacity: [Weekday: Int],
    dayHours: [Weekday: DayHours] = [:], themeAccent: ThemeAccent = .navy,
    dayChangesAt: Int = Settings.defaultDayChangesAt
  ) {
    self.dayChangesAt = dayChangesAt
    self.defaultEstimateMinutes = defaultEstimateMinutes
    self.bufferPercentage = bufferPercentage
    self.capacity = capacity
    self.dayHours = dayHours
    self.themeAccent = themeAccent
  }
}

// Resolving `Settings` from the raw values `LibraryState` holds, and applying the one event that
// changes them. In its own file (SwiftLint file_length) rather than suppressed.
extension LibraryState {
  /// Sets or, with no value, clears a global or per-view setting. Ignores a key this build does not
  /// recognise.
  mutating func change(_ changed: SettingChanged) {
    guard let key = SettingKey(rawValue: changed.key) else { return }
    if let viewID = changed.viewID {
      if let value = changed.value {
        viewSettingOverrides[viewID, default: [:]][key] = value
      } else {
        viewSettingOverrides[viewID]?.removeValue(forKey: key)
      }
    } else if let value = changed.value {
      globalSettingValues[key] = value
    } else {
      globalSettingValues.removeValue(forKey: key)
    }
  }

  /// The settings the view `viewID` plans with: its own overrides, then the global values, then the
  /// built-in defaults.
  public func settings(for viewID: ViewID) -> Settings {
    resolvedSettings(override: viewSettingOverrides[viewID] ?? [:])
  }

  /// The settings with no per-view override applied.
  public var globalSettings: Settings {
    resolvedSettings(override: [:])
  }

  /// Whether `key` is overridden for the view `viewID`, rather than inherited from the global value.
  public func isOverridden(_ key: SettingKey, in viewID: ViewID) -> Bool {
    viewSettingOverrides[viewID]?[key] != nil
  }

  /// The default view: the one chosen in settings, or the
  /// built-in default view if none was chosen or the one chosen no longer exists.
  public var defaultViewID: ViewID {
    let chosen = globalSettingValues[.defaultViewID].map(ViewID.init) ?? .default
    return hasView(chosen) ? chosen : .default
  }

  func globalSettingValue(_ key: SettingKey) -> String? {
    globalSettingValues[key]
  }

  func overrideValue(_ key: SettingKey, in viewID: ViewID) -> String? {
    viewSettingOverrides[viewID]?[key]
  }

  private func resolvedSettings(override: [SettingKey: String]) -> Settings {
    func value(_ key: SettingKey) -> String? { override[key] ?? globalSettingValues[key] }
    let capacity = Dictionary(
      uniqueKeysWithValues: Weekday.allCases.map { weekday in
        (weekday, value(weekday.capacityKey).flatMap(Int.init) ?? weekday.builtInCapacityMinutes)
      })
    let dayHours = Dictionary(
      uniqueKeysWithValues: Weekday.allCases.map { weekday in
        let hours = DayHours(
          start: value(weekday.startKey).flatMap(Int.init) ?? DayHours.builtIn.start,
          end: value(weekday.endKey).flatMap(Int.init) ?? DayHours.builtIn.end)
        return (weekday, hours.isValid ? hours : .builtIn)
      })
    var dayChangesAt = Settings.defaultDayChangesAt
    if let changesAt = value(.dayChangesAt).flatMap(Int.init), (0...Settings.latestDayChangesAt).contains(changesAt) {
      dayChangesAt = changesAt
    }
    return Settings(
      defaultEstimateMinutes: value(.defaultEstimateMinutes).flatMap(Int.init) ?? Settings.defaultEstimateMinutes,
      bufferPercentage: value(.bufferPercentage).flatMap(Int.init) ?? Settings.defaultBufferPercentage,
      capacity: capacity,
      dayHours: dayHours,
      themeAccent: value(.themeAccent).flatMap(ThemeAccent.init) ?? .navy,
      dayChangesAt: dayChangesAt
    )
  }
}
