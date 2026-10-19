import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Observation
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
@Suite("When another view's settings are changed from the settings place")
struct ChangeSettingsOfAnotherViewTests {
  static let work = ViewID("work")
  static let events = [viewCreated("work", "Work", lamport: 1)]

  @Test("its accent changes and the view shown keeps its own")
  func itsAccentChangesAndTheViewShownKeepsItsOwn() {
    let (library, log) = makeLibrary(Self.events)

    library.changeAccent(.plum, for: Self.work)

    #expect(library.settings(of: Self.work).themeAccent == .plum)
    #expect(library.viewSettings.themeAccent == .navy)
    #expect(library.isOverridden(.themeAccent, in: Self.work))
    #expect(log.events.last == settingChanged(.themeAccent, to: "plum", view: "work", id: "id-1", lamport: 2))
  }

  @Test("clearing its accent follows the global one again")
  func clearingItsAccentFollowsTheGlobalOne() {
    let (library, _) = makeLibrary(Self.events)
    library.changeGlobalAccent(.alpine)
    library.changeAccent(.plum, for: Self.work)

    library.changeAccent(nil, for: Self.work)

    #expect(library.settings(of: Self.work).themeAccent == .alpine)
    #expect(!library.isOverridden(.themeAccent, in: Self.work))
  }

  @Test("its capacity changes for it alone")
  func itsCapacityChangesForItAlone() {
    let (library, _) = makeLibrary(Self.events)

    library.changeCapacity(.friday, minutes: 240, for: Self.work)

    #expect(library.settings(of: Self.work).capacity[.friday] == 240)
    #expect(library.viewSettings.capacity[.friday] == 480)
  }

  @Test("the view shown sees the change when it is the one changed")
  func theViewShownSeesTheChange() {
    let (library, _) = makeLibrary(Self.events)

    library.changeAccent(.forest, for: .default)

    #expect(library.viewSettings.themeAccent == .forest)
  }
}

@MainActor
@Suite("When a view is edited from the view switcher")
struct EditViewTests {
  @Test("the settings place opens on that view, and the view shown does not change")
  func theSettingsPlaceOpensOnThatView() {
    let (library, _) = makeLibrary([viewCreated("work", "Work", lamport: 1)])

    library.editView(ViewID("work"))

    #expect(library.section == .settings)
    #expect(library.viewBeingEdited == ViewID("work"))
    #expect(library.currentView == .default)
  }

  @Test("with none picked, the view shown is the one edited")
  func withNonePickedTheViewShownIsEdited() {
    let (library, _) = makeLibrary([viewCreated("work", "Work", lamport: 1)], view: ViewID("work"))

    #expect(library.viewBeingEdited == nil)
    #expect(library.viewEdited == ViewID("work"))
  }

  @Test("opening the settings place the usual way edits the view shown again")
  func openingSettingsTheUsualWayEditsTheViewShown() {
    let (library, _) = makeLibrary([viewCreated("work", "Work", lamport: 1)])
    library.editView(ViewID("work"))

    library.show(.inbox)
    library.show(.settings)

    #expect(library.viewBeingEdited == nil)
    #expect(library.viewEdited == .default)
  }
}

/// Set from the observer's `@Sendable` callback, which runs on the thread that made the change.
private final class Flag: @unchecked Sendable {
  var isSet = false
}

@MainActor
@Suite("When a screen shows the settings of a view")
struct ObserveViewSettingsTests {
  static let work = ViewID("work")

  @Test("it is told when another view's accent changes")
  func itIsToldWhenAnotherViewsAccentChanges() {
    let (library, _) = makeLibrary([viewCreated("work", "Work", lamport: 1)])
    let told = Flag()
    withObservationTracking {
      _ = library.settings(of: Self.work)
      _ = library.isOverridden(.themeAccent, in: Self.work)
    } onChange: {
      told.isSet = true
    }

    library.changeAccent(.plum, for: Self.work)

    #expect(told.isSet)
  }

  @Test("it is told when the view shown has a setting overridden")
  func itIsToldWhenTheViewShownHasASettingOverridden() {
    let (library, _) = makeLibrary()
    let told = Flag()
    withObservationTracking {
      _ = library.isOverridden(.bufferPercentage, in: .default)
    } onChange: {
      told.isSet = true
    }

    library.changeSetting(.bufferPercentage, to: "10", for: .default)

    #expect(told.isSet)
  }
}
