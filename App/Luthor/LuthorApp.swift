import Foundation
import LuthorDomain
import LuthorStore
import LuthorViewModels
import SwiftUI

@main
struct LuthorApp: App {
  private let configuration: LuthorConfiguration
  @State private var library: LibraryViewModel

  init() {
    let configuration = LuthorConfiguration(
      environment: ProcessInfo.processInfo.environment,
      home: FileManager.default.homeDirectoryForCurrentUser
    )
    let library = LibraryViewModel(
      log: JSONLinesEventLog(fileURL: configuration.logURL),
      commands: Commands(deviceID: configuration.deviceID, ids: UUIDGenerator())
    )
    library.reload()
    self.configuration = configuration
    _library = State(initialValue: library)
  }

  var body: some Scene {
    Window("Luthor", id: "library") {
      LibraryView(library: library, logURL: configuration.logURL)
    }
    .defaultSize(width: 760, height: 640)
    .commands {
      CommandMenu("Task") {
        Button("Complete") { library.completeSelected() }
          .keyboardShortcut(.return, modifiers: .command)
          .disabled(library.selection == nil)
        Divider()
        // ⌥⌘1 to ⌥⌘9 file the selected task into the first nine projects.
        Menu("Move to Project") {
          ForEach(Array(library.projects.enumerated()), id: \.element.id) { position, project in
            Button(project.title) { library.fileSelected(into: project.id) }
              .keyboardShortcut(Self.shortcut(for: position))
          }
        }
        .disabled(library.selection == nil || library.projects.isEmpty)
      }
    }
  }

  private static func shortcut(for position: Int) -> KeyboardShortcut? {
    guard position < 9, let digit = "123456789".dropFirst(position).first else { return nil }
    return KeyboardShortcut(KeyEquivalent(digit), modifiers: [.command, .option])
  }
}
