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

  /// The view `luthor add` and imports use when none is named: the one chosen in settings, or the
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
    return Settings(
      defaultEstimateMinutes: value(.defaultEstimateMinutes).flatMap(Int.init) ?? Settings.defaultEstimateMinutes,
      bufferPercentage: value(.bufferPercentage).flatMap(Int.init) ?? Settings.defaultBufferPercentage,
      capacity: capacity
    )
  }
}
