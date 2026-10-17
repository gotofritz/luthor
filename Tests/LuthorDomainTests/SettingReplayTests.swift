import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When no setting has ever been changed")
struct DefaultSettingsTests {
  @Test("the built-in defaults apply")
  func builtInDefaultsApply() {
    let settings = LibraryState.replay([]).settings(for: .default)

    #expect(settings.defaultEstimateMinutes == 5)
    #expect(settings.bufferPercentage == 40)
    #expect(settings.capacity[.monday] == 480)
    #expect(settings.capacity[.friday] == 480)
    #expect(settings.capacity[.saturday] == 0)
    #expect(settings.capacity[.sunday] == 0)
  }

  @Test("the default view is the built-in default view")
  func defaultViewIsTheBuiltInOne() {
    #expect(LibraryState.replay([]).defaultViewID == .default)
  }
}

@Suite("When a global setting is changed")
struct GlobalSettingReplayTests {
  @Test("every view resolves to the new value")
  func everyViewResolvesToIt() {
    let state = LibraryState.replay([
      viewCreated("work", "Work", lamport: 1),
      settingChanged(.bufferPercentage, to: "20", lamport: 2),
    ])

    #expect(state.settings(for: .default).bufferPercentage == 20)
    #expect(state.settings(for: ViewID("work")).bufferPercentage == 20)
    #expect(state.globalSettings.bufferPercentage == 20)
  }

  @Test("the last value wins")
  func lastValueWins() {
    let state = LibraryState.replay([
      settingChanged(.bufferPercentage, to: "20", lamport: 1),
      settingChanged(.bufferPercentage, to: "30", lamport: 2),
    ])

    #expect(state.globalSettings.bufferPercentage == 30)
  }

  @Test("clearing it falls back to the built-in default")
  func clearingFallsBackToTheBuiltInDefault() {
    let state = LibraryState.replay([
      settingChanged(.bufferPercentage, to: "20", lamport: 1),
      settingChanged(.bufferPercentage, to: nil, lamport: 2),
    ])

    #expect(state.globalSettings.bufferPercentage == 40)
  }

  @Test("a value that fails to parse is ignored, as an unknown value would be")
  func unparsableValueIsIgnored() {
    let state = LibraryState.replay([settingChanged(.bufferPercentage, to: "not a number", lamport: 1)])

    #expect(state.globalSettings.bufferPercentage == 40)
  }
}

@Suite("When a setting is overridden for a view")
struct ViewSettingOverrideReplayTests {
  static let base = [viewCreated("work", "Work", lamport: 1)]

  @Test("that view resolves to the override; others still resolve to the global value")
  func onlyThatViewSeesTheOverride() {
    let state = LibraryState.replay(
      Self.base + [
        settingChanged(.bufferPercentage, to: "20", lamport: 2),
        settingChanged(.bufferPercentage, to: "5", view: "work", lamport: 3),
      ])

    #expect(state.settings(for: ViewID("work")).bufferPercentage == 5)
    #expect(state.settings(for: .default).bufferPercentage == 20)
    #expect(state.isOverridden(.bufferPercentage, in: ViewID("work")))
    #expect(!state.isOverridden(.bufferPercentage, in: .default))
  }

  @Test("clearing the override falls back to the global value")
  func clearingFallsBackToTheGlobalValue() {
    let state = LibraryState.replay(
      Self.base + [
        settingChanged(.bufferPercentage, to: "20", lamport: 2),
        settingChanged(.bufferPercentage, to: "5", view: "work", lamport: 3),
        settingChanged(.bufferPercentage, to: nil, view: "work", lamport: 4),
      ])

    #expect(state.settings(for: ViewID("work")).bufferPercentage == 20)
    #expect(!state.isOverridden(.bufferPercentage, in: ViewID("work")))
  }

  @Test("capacity is overridden per weekday independently")
  func capacityIsOverriddenPerWeekday() {
    let state = LibraryState.replay(Self.base + [settingChanged(.capacityFriday, to: "240", view: "work", lamport: 2)])

    #expect(state.settings(for: ViewID("work")).capacity[.friday] == 240)
    #expect(state.settings(for: ViewID("work")).capacity[.monday] == 480)
  }

  @Test("an override for a view that is not active is ignored")
  func overrideForAnUnknownViewIsIgnored() {
    let state = LibraryState.replay([settingChanged(.bufferPercentage, to: "5", view: "gone", lamport: 1)])

    #expect(state.globalSettings.bufferPercentage == 40)
  }
}

@Suite("When the default view is changed")
struct DefaultViewReplayTests {
  @Test("the library resolves to it")
  func libraryResolvesToIt() {
    let state = LibraryState.replay([
      viewCreated("work", "Work", lamport: 1),
      settingChanged(.defaultViewID, to: "work", lamport: 2),
    ])

    #expect(state.defaultViewID == ViewID("work"))
  }

  @Test("a default view that no longer exists falls back to the built-in default view")
  func unknownDefaultViewFallsBack() {
    let state = LibraryState.replay([settingChanged(.defaultViewID, to: "gone", lamport: 1)])

    #expect(state.defaultViewID == .default)
  }
}
