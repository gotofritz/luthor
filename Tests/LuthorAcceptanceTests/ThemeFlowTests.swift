import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given several views, when each is given its own accent")
struct ThemeFlowTests {
  @Test("the window takes the accent of the view shown, and it survives a restart")
  func windowTakesTheAccentOfTheViewShown() throws {
    let dir = try TemporaryDirectory()
    defer { dir.remove() }
    let library = launchApp(on: dir.file("events.jsonl"))
    let work = try library.createView("Work")

    library.changeGlobalAccent(.alpine)
    library.showView(work)
    library.changeAccentForCurrentView(.plum)

    #expect(library.viewSettings.themeAccent == .plum)
    library.showView(.default)
    #expect(library.viewSettings.themeAccent == .alpine)

    let restarted = launchApp(on: dir.file("events.jsonl"), view: work)
    #expect(restarted.viewSettings.themeAccent == .plum)
  }
}
