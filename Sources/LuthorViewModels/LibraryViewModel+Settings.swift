import LuthorDomain

// Settings: global values and per-view overrides. In its own file (SwiftLint file_length) rather
// than suppressed.
extension LibraryViewModel {
  /// Changes a global setting, or with `nil` clears it back to the built-in default.
  public func changeGlobalSetting(_ key: SettingKey, to value: String?) {
    perform { (log) throws(CommandError) in try commands.changeSetting(key, to: value, log: log) }
  }

  /// Overrides a setting for the current view, or with `nil` clears the override back to the global
  /// value.
  public func changeSettingForCurrentView(_ key: SettingKey, to value: String?) {
    let viewID = currentView
    perform { (log) throws(CommandError) in try commands.changeSetting(key, to: value, for: viewID, log: log) }
  }

  /// Changes the global capacity of a weekday, or with `nil` clears it back to the built-in default.
  public func changeGlobalCapacity(_ weekday: Weekday, minutes: Int?) {
    changeGlobalSetting(weekday.capacityKey, to: minutes.map(String.init))
  }

  /// Overrides the capacity of a weekday for the current view, or with `nil` clears the override.
  public func changeCapacityForCurrentView(_ weekday: Weekday, minutes: Int?) {
    changeSettingForCurrentView(weekday.capacityKey, to: minutes.map(String.init))
  }

  /// Whether `key` is overridden for the current view, rather than inherited from the global value.
  public func isOverriddenForCurrentView(_ key: SettingKey) -> Bool {
    state.isOverridden(key, in: currentView)
  }

  /// Whether a weekday's capacity is overridden for the current view.
  public func isCapacityOverriddenForCurrentView(_ weekday: Weekday) -> Bool {
    isOverriddenForCurrentView(weekday.capacityKey)
  }

  /// Sets the view `luthor add` and imports use when none is named.
  public func setDefaultView(_ viewID: ViewID) {
    perform { (log) throws(CommandError) in try commands.setDefaultView(viewID, log: log) }
  }
}
