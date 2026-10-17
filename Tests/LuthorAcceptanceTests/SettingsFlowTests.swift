import Foundation
import LuthorCLI
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given the settings place, when planning numbers are set")
struct SettingsFlowTests {
  @Test("a global number applies everywhere, and a view can override it")
  func globalAppliesEverywhereAndAViewCanOverrideIt() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let work = try library.createView("Work")

    library.show(.settings)
    library.changeGlobalSetting(.bufferPercentage, to: "25")
    library.showView(work)
    library.changeSettingForCurrentView(.bufferPercentage, to: "10")

    #expect(library.viewSettings.bufferPercentage == 10)
    library.showView(.default)
    #expect(library.viewSettings.bufferPercentage == 25)
  }

  @Test("the default view chosen in settings is the one luthor add uses without --view")
  func defaultViewIsTheOneAddUsesWithoutView() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let logURL = dir.file("events.jsonl")
    let library = launchApp(on: logURL)
    let work = try library.createView("Work")
    library.setDefaultView(work)

    let cli = CLI(
      environment: ["LUTHOR_LOG": logURL.path, "LUTHOR_DEVICE_ID": "mac"],
      home: dir.file("home"), ids: UUIDGenerator())
    let result = cli.run(["add", "book flights"])

    #expect(result.exitCode == 0)
    library.reload()
    library.showView(work)
    #expect(library.tasks.map(\.title) == ["book flights"])
  }
}
