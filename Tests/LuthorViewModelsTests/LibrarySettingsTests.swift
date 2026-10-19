import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
private func makeLibrary(_ events: [EventEnvelope] = [], view: ViewID = .default) -> (
  LibraryViewModel, InMemoryEventLog
) {
  let log = InMemoryEventLog(events)
  let library = LibraryViewModel(
    log: log, commands: Commands(deviceID: DeviceID("mac"), ids: SequentialIDs()), view: view)
  library.reload()
  return (library, log)
}

@MainActor
@Suite("When the settings place is shown")
struct SettingsNavigationTests {
  @Test("it has no project path and no task selected")
  func showingSettingsClearsThePathAndSelection() {
    let (library, _) = makeLibrary([
      projectCreated("p1", "Move house", lamport: 1), captured("t1", "pay rent", lamport: 2),
    ])
    library.open(.project(TaskID("p1")))
    library.selection = TaskID("t1")

    library.show(.settings)

    #expect(library.section == .settings)
    #expect(library.selection == nil)
  }
}

@MainActor
@Suite("When a global setting is changed from the settings place")
struct ChangeGlobalSettingViewModelTests {
  @Test("the global settings resolve to the new value")
  func globalSettingsResolveToIt() {
    let (library, log) = makeLibrary([viewCreated("work", "Work", lamport: 1)])

    library.changeGlobalSetting(.bufferPercentage, to: "20")

    #expect(library.globalSettings.bufferPercentage == 20)
    #expect(log.events.last == settingChanged(.bufferPercentage, to: "20", id: "id-1", lamport: 2))
  }

  @Test("the weekday capacity changes through a dedicated action")
  func capacityChangesThroughADedicatedAction() {
    let (library, _) = makeLibrary()

    library.changeGlobalCapacity(.friday, minutes: 240)

    #expect(library.globalSettings.capacity[.friday] == 240)
  }
}

@MainActor
@Suite("When a setting is overridden for the current view")
struct ChangeViewSettingViewModelTests {
  @Test("the current view resolves to the override, and is marked overridden")
  func currentViewResolvesToTheOverride() {
    let (library, _) = makeLibrary([viewCreated("work", "Work", lamport: 1)], view: ViewID("work"))

    library.changeSettingForCurrentView(.bufferPercentage, to: "10")

    #expect(library.viewSettings.bufferPercentage == 10)
    #expect(library.isOverriddenForCurrentView(.bufferPercentage))
  }

  @Test("capacity overrides through a dedicated action")
  func capacityOverridesThroughADedicatedAction() {
    let (library, _) = makeLibrary([viewCreated("work", "Work", lamport: 1)], view: ViewID("work"))

    library.changeCapacityForCurrentView(.friday, minutes: 100)

    #expect(library.viewSettings.capacity[.friday] == 100)
    #expect(library.isCapacityOverriddenForCurrentView(.friday))
  }

  @Test("clearing the override falls back to the global value")
  func clearingFallsBackToTheGlobalValue() {
    let (library, _) = makeLibrary([viewCreated("work", "Work", lamport: 1)], view: ViewID("work"))
    library.changeGlobalSetting(.bufferPercentage, to: "20")
    library.changeSettingForCurrentView(.bufferPercentage, to: "10")

    library.changeSettingForCurrentView(.bufferPercentage, to: nil)

    #expect(library.viewSettings.bufferPercentage == 20)
    #expect(!library.isOverriddenForCurrentView(.bufferPercentage))
  }

  @Test("switching view shows that view's own settings")
  func switchingViewShowsItsOwnSettings() {
    let (library, _) = makeLibrary([viewCreated("work", "Work", lamport: 1)])
    library.showView(ViewID("work"))
    library.changeSettingForCurrentView(.bufferPercentage, to: "10")

    library.showView(.default)

    #expect(library.viewSettings.bufferPercentage == 40)
  }
}

@MainActor
@Suite("When the default view is set from the settings place")
struct SetDefaultViewViewModelTests {
  @Test("the library resolves to it")
  func libraryResolvesToIt() {
    let (library, _) = makeLibrary([viewCreated("work", "Work", lamport: 1)])

    library.setDefaultView(ViewID("work"))

    #expect(library.defaultViewID == ViewID("work"))
  }
}

@MainActor
@Suite("When an accent is chosen for the current view")
struct ChangeAccentViewModelTests {
  @Test("the view resolves to it, and another view keeps the global accent")
  func theViewResolvesToIt() {
    let (library, log) = makeLibrary([viewCreated("work", "Work", lamport: 1)], view: ViewID("work"))

    library.changeAccentForCurrentView(.forest)

    #expect(library.viewSettings.themeAccent == .forest)
    #expect(library.isOverriddenForCurrentView(.themeAccent))
    #expect(log.events.last == settingChanged(.themeAccent, to: "forest", view: "work", id: "id-1", lamport: 2))
    library.showView(.default)
    #expect(library.viewSettings.themeAccent == .navy)
  }

  @Test("clearing it follows the global accent again")
  func clearingFollowsTheGlobalAccent() {
    let (library, _) = makeLibrary([viewCreated("work", "Work", lamport: 1)], view: ViewID("work"))
    library.changeGlobalAccent(.alpine)
    library.changeAccentForCurrentView(.forest)

    library.changeAccentForCurrentView(nil)

    #expect(library.viewSettings.themeAccent == .alpine)
    #expect(!library.isOverriddenForCurrentView(.themeAccent))
  }
}
