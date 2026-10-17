import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

@MainActor
@Suite("Given a Mac where Luthor has never been started")
struct StorageSetupFlowTests {
  private func startUp(home: TemporaryDirectory, saved: LogStorage? = nil) -> StorageController {
    StorageController(saved: saved, home: home.url, deviceID: DeviceID("desk"), save: { _ in })
  }

  private func open(_ controller: StorageController, home: TemporaryDirectory) throws -> LibraryViewModel {
    let configuration = LuthorConfiguration(
      environment: [:], home: home.url, hostName: "desk", storage: try #require(controller.storage))
    return launchApp(configuration: configuration)
  }

  @Test("choosing the Home Folder keeps the log in ~/.luthor/events.jsonl")
  func homeFolderChoice() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let controller = startUp(home: home)
    #expect(controller.needsSetup)

    controller.kind = .homeFolder
    controller.confirm()
    let library = try open(controller, home: home)
    library.capture("buy milk")

    #expect(FileManager.default.fileExists(atPath: home.file(".luthor/events.jsonl").path))
    #expect(library.tasks.map(\.title) == ["buy milk"])
  }

  @Test("choosing Dropbox creates ~/Dropbox/backups/Luthor and keeps the log there")
  func dropboxChoice() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let controller = startUp(home: home)

    controller.confirm()
    let library = try open(controller, home: home)
    library.capture("buy milk")

    #expect(FileManager.default.fileExists(atPath: home.file("Dropbox/backups/Luthor/events-desk.jsonl").path))
    #expect(library.tasks.map(\.title) == ["buy milk"])
  }

  @Test("moving from the Home Folder to Dropbox brings the tasks along")
  func movingToDropboxKeepsTheTasks() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let controller = startUp(home: home)
    controller.kind = .homeFolder
    controller.confirm()
    try open(controller, home: home).capture("buy milk")

    controller.kind = .dropbox
    controller.confirm()
    let library = try open(controller, home: home)

    #expect(library.tasks.map(\.title) == ["buy milk"])
  }

  @Test("the choice is remembered, so the next start does not ask")
  func choiceSurvivesARestart() throws {
    let home = try TemporaryDirectory()
    defer { home.remove() }
    let first = startUp(home: home)
    first.confirm()

    let next = startUp(home: home, saved: first.storage)

    #expect(next.needsSetup == false)
    #expect(next.storage == first.storage)
  }
}
