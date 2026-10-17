import LuthorDomain
import LuthorTestSupport
import Testing

private func makeCommands() -> Commands {
  Commands(deviceID: DeviceID("mac"), ids: SequentialIDs())
}

@Suite("When a global setting is changed by command")
struct ChangeGlobalSettingCommandTests {
  @Test("it writes one SettingChanged with no view")
  func changingWritesSettingChanged() throws {
    let events = try makeCommands().changeSetting(.bufferPercentage, to: "25", log: [])

    #expect(events == [settingChanged(.bufferPercentage, to: "25", id: "id-1", lamport: 1)])
  }

  @Test("clearing it writes one SettingChanged with no value")
  func clearingWritesSettingChangedWithoutValue() throws {
    let log = [settingChanged(.bufferPercentage, to: "25", lamport: 1)]

    let events = try makeCommands().changeSetting(.bufferPercentage, to: nil, log: log)

    #expect(events == [settingChanged(.bufferPercentage, to: nil, id: "id-1", lamport: 2)])
  }

  @Test("giving a setting the value it has writes nothing")
  func sameValueWritesNothing() throws {
    let log = [settingChanged(.bufferPercentage, to: "25", lamport: 1)]

    #expect(try makeCommands().changeSetting(.bufferPercentage, to: "25", log: log) == [])
  }

  @Test("clearing a setting that is not set writes nothing")
  func clearingUnsetWritesNothing() throws {
    #expect(try makeCommands().changeSetting(.bufferPercentage, to: nil, log: []) == [])
  }
}

@Suite("When a setting is overridden for a view by command")
struct ChangeViewSettingCommandTests {
  static let log = [viewCreated("work", "Work", lamport: 1)]

  @Test("it writes one SettingChanged carrying the view")
  func overridingWritesSettingChanged() throws {
    let events = try makeCommands().changeSetting(.bufferPercentage, to: "10", for: ViewID("work"), log: Self.log)

    #expect(events == [settingChanged(.bufferPercentage, to: "10", view: "work", id: "id-1", lamport: 2)])
  }

  @Test("clearing the override writes one SettingChanged with no value")
  func clearingWritesSettingChangedWithoutValue() throws {
    let log = Self.log + [settingChanged(.bufferPercentage, to: "10", view: "work", lamport: 2)]

    let events = try makeCommands().changeSetting(.bufferPercentage, to: nil, for: ViewID("work"), log: log)

    #expect(events == [settingChanged(.bufferPercentage, to: nil, view: "work", id: "id-1", lamport: 3)])
  }

  @Test("giving the override the value it has writes nothing")
  func sameValueWritesNothing() throws {
    let log = Self.log + [settingChanged(.bufferPercentage, to: "10", view: "work", lamport: 2)]

    #expect(try makeCommands().changeSetting(.bufferPercentage, to: "10", for: ViewID("work"), log: log) == [])
  }

  @Test("overriding a setting for a view that does not exist is refused")
  func unknownViewIsRefused() {
    #expect(throws: CommandError.noView(ViewID("gone"))) {
      try makeCommands().changeSetting(.bufferPercentage, to: "10", for: ViewID("gone"), log: [])
    }
  }
}

@Suite("When the default view is set by command")
struct SetDefaultViewCommandTests {
  @Test("it writes one SettingChanged for defaultViewID")
  func settingWritesSettingChanged() throws {
    let log = [viewCreated("work", "Work", lamport: 1)]

    let events = try makeCommands().setDefaultView(ViewID("work"), log: log)

    #expect(events == [settingChanged(.defaultViewID, to: "work", id: "id-1", lamport: 2)])
  }

  @Test("setting it to a view that does not exist is refused")
  func unknownViewIsRefused() {
    #expect(throws: CommandError.noView(ViewID("gone"))) {
      try makeCommands().setDefaultView(ViewID("gone"), log: [])
    }
  }
}
