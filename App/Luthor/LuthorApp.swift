import Foundation
import LuthorDomain
import LuthorStore
import LuthorViewModels
import SwiftUI

@main
struct LuthorApp: App {
  private let configuration: LuthorConfiguration
  @State private var inbox: InboxViewModel

  init() {
    let configuration = LuthorConfiguration(
      environment: ProcessInfo.processInfo.environment,
      home: FileManager.default.homeDirectoryForCurrentUser
    )
    let inbox = InboxViewModel(
      log: JSONLinesEventLog(fileURL: configuration.logURL),
      commands: Commands(deviceID: configuration.deviceID, ids: UUIDGenerator())
    )
    inbox.reload()
    self.configuration = configuration
    _inbox = State(initialValue: inbox)
  }

  var body: some Scene {
    Window("Inbox", id: "inbox") {
      InboxView(inbox: inbox, logURL: configuration.logURL)
    }
    .defaultSize(width: 520, height: 640)
    .commands {
      CommandMenu("Task") {
        Button("Complete") { inbox.completeSelected() }
          .keyboardShortcut(.return, modifiers: .command)
          .disabled(inbox.selection == nil)
      }
    }
  }
}
