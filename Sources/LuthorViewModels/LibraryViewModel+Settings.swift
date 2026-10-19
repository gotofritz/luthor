import LuthorDomain

// Settings: global values and per-view overrides. In its own file (SwiftLint file_length) rather
// than suppressed.
extension LibraryViewModel {
  /// Changes a global setting, or with `nil` clears it back to the built-in default.
  public func changeGlobalSetting(_ key: SettingKey, to value: String?) {
    perform { (log) throws(CommandError) in try commands.changeSetting(key, to: value, log: log) }
  }

  /// Overrides a setting for the view `viewID`, or with `nil` clears the override back to the global value.
  public func changeSetting(_ key: SettingKey, to value: String?, for viewID: ViewID) {
    perform { (log) throws(CommandError) in try commands.changeSetting(key, to: value, for: viewID, log: log) }
  }

  /// Overrides a setting for the current view, or with `nil` clears the override back to the global
  /// value.
  public func changeSettingForCurrentView(_ key: SettingKey, to value: String?) {
    changeSetting(key, to: value, for: currentView)
  }

  /// The settings the view `viewID` plans with, which need not be the view shown.
  public func settings(of viewID: ViewID) -> Settings {
    settingsByView[viewID] ?? state.settings(for: viewID)
  }

  /// Whether `key` is overridden for the view `viewID`, rather than inherited from the global value.
  public func isOverridden(_ key: SettingKey, in viewID: ViewID) -> Bool {
    overriddenKeysByView[viewID]?.contains(key) ?? state.isOverridden(key, in: viewID)
  }

  /// Overrides the capacity of a weekday for the view `viewID`, or with `nil` clears the override.
  public func changeCapacity(_ weekday: Weekday, minutes: Int?, for viewID: ViewID) {
    changeSetting(weekday.capacityKey, to: minutes.map(String.init), for: viewID)
  }

  /// Overrides the accent of the view `viewID`, or with `nil` clears the override.
  public func changeAccent(_ accent: ThemeAccent?, for viewID: ViewID) {
    changeSetting(.themeAccent, to: accent?.rawValue, for: viewID)
  }

  /// Opens the settings place on the view `viewID`, which need not be the view shown.
  public func editView(_ viewID: ViewID) {
    show(.settings)
    viewBeingEdited = viewID
  }

  /// The view whose settings the settings place shows: the one picked, else the view shown.
  public var viewEdited: ViewID {
    viewBeingEdited ?? currentView
  }

  /// Changes the global capacity of a weekday, or with `nil` clears it back to the built-in default.
  public func changeGlobalCapacity(_ weekday: Weekday, minutes: Int?) {
    changeGlobalSetting(weekday.capacityKey, to: minutes.map(String.init))
  }

  /// Overrides the capacity of a weekday for the current view, or with `nil` clears the override.
  public func changeCapacityForCurrentView(_ weekday: Weekday, minutes: Int?) {
    changeSettingForCurrentView(weekday.capacityKey, to: minutes.map(String.init))
  }

  /// Changes the global accent, or with `nil` clears it back to the built-in one.
  public func changeGlobalAccent(_ accent: ThemeAccent?) {
    changeGlobalSetting(.themeAccent, to: accent?.rawValue)
  }

  /// Overrides the accent for the current view, or with `nil` clears the override.
  public func changeAccentForCurrentView(_ accent: ThemeAccent?) {
    changeAccent(accent, for: currentView)
  }

  /// Whether `key` is overridden for the current view, rather than inherited from the global value.
  public func isOverriddenForCurrentView(_ key: SettingKey) -> Bool {
    isOverridden(key, in: currentView)
  }

  /// Whether a weekday's capacity is overridden for the current view.
  public func isCapacityOverriddenForCurrentView(_ weekday: Weekday) -> Bool {
    isOverriddenForCurrentView(weekday.capacityKey)
  }

  /// Sets the default view.
  public func setDefaultView(_ viewID: ViewID) {
    perform { (log) throws(CommandError) in try commands.setDefaultView(viewID, log: log) }
  }
}
