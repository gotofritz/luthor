import LuthorDomain
import LuthorTestSupport
import Testing

@Suite("When no accent has ever been chosen")
struct DefaultThemeAccentTests {
  @Test("every view resolves to the built-in accent")
  func everyViewResolvesToTheBuiltInAccent() {
    let state = LibraryState.replay([viewCreated("work", "Work", lamport: 1)])

    #expect(state.settings(for: .default).themeAccent == .navy)
    #expect(state.settings(for: ViewID("work")).themeAccent == .navy)
    #expect(state.globalSettings.themeAccent == .navy)
  }
}

@Suite("When an accent is chosen")
struct ThemeAccentReplayTests {
  static let base = [viewCreated("work", "Work", lamport: 1)]

  @Test("a global accent applies to every view", arguments: ThemeAccent.allCases)
  func globalAccentAppliesToEveryView(accent: ThemeAccent) {
    let state = LibraryState.replay(
      Self.base + [settingChanged(.themeAccent, to: accent.rawValue, lamport: 2)])

    #expect(state.settings(for: .default).themeAccent == accent)
    #expect(state.settings(for: ViewID("work")).themeAccent == accent)
  }

  @Test("a view's own accent wins over the global one, and only for that view")
  func viewAccentWinsOverTheGlobalOne() {
    let state = LibraryState.replay(
      Self.base + [
        settingChanged(.themeAccent, to: "alpine", lamport: 2),
        settingChanged(.themeAccent, to: "plum", view: "work", lamport: 3),
      ])

    #expect(state.settings(for: ViewID("work")).themeAccent == .plum)
    #expect(state.settings(for: .default).themeAccent == .alpine)
    #expect(state.isOverridden(.themeAccent, in: ViewID("work")))
  }

  @Test("clearing a view's accent falls back to the global one")
  func clearingFallsBackToTheGlobalAccent() {
    let state = LibraryState.replay(
      Self.base + [
        settingChanged(.themeAccent, to: "alpine", lamport: 2),
        settingChanged(.themeAccent, to: "plum", view: "work", lamport: 3),
        settingChanged(.themeAccent, to: nil, view: "work", lamport: 4),
      ])

    #expect(state.settings(for: ViewID("work")).themeAccent == .alpine)
  }

  @Test("an accent this build does not know is ignored, as an unparsable number is")
  func unknownAccentIsIgnored() {
    let state = LibraryState.replay([settingChanged(.themeAccent, to: "chartreuse", lamport: 1)])

    #expect(state.globalSettings.themeAccent == .navy)
  }
}
