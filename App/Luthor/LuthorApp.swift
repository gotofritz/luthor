import Foundation
import LuthorDomain
import LuthorStore
import LuthorViewModels
import SwiftUI

@main
struct LuthorApp: App {
  /// The `UserDefaults` key of the view shown last; per device, so it stays out of the log.
  private static let lastViewKey = "lastViewID"

  private let configuration: LuthorConfiguration
  @State private var library: LibraryViewModel

  init() {
    let configuration = LuthorConfiguration(
      environment: ProcessInfo.processInfo.environment,
      home: FileManager.default.homeDirectoryForCurrentUser
    )
    let library = LibraryViewModel(
      log: JSONLinesEventLog(fileURL: configuration.logURL),
      commands: Commands(deviceID: configuration.deviceID, ids: UUIDGenerator()),
      view: UserDefaults.standard.string(forKey: Self.lastViewKey).map(ViewID.init) ?? .default
    )
    library.reload()
    self.configuration = configuration
    _library = State(initialValue: library)
  }

  var body: some Scene {
    Window("Luthor", id: "library") {
      LibraryView(library: library, logURL: configuration.logURL)
        .onChange(of: library.currentView, initial: true) { _, view in
          UserDefaults.standard.set(view.rawValue, forKey: Self.lastViewKey)
        }
    }
    .defaultSize(width: 760, height: 640)
    .commands {
      // ⌃⌘1 to ⌃⌘9 show the first nine views, in the View menu.
      CommandGroup(before: .sidebar) {
        ForEach(Array(library.views.enumerated()), id: \.element.id) { position, view in
          Toggle(
            view.name, isOn: Binding(get: { library.currentView == view.id }, set: { _ in library.showView(view.id) })
          )
          .keyboardShortcut(Self.shortcut(for: position, modifiers: [.command, .control]))
        }
        Divider()
      }
      CommandMenu("Task") {
        Button("Complete") { library.completeSelected() }
          .keyboardShortcut(.return, modifiers: .command)
          .disabled(library.selection == nil)
        Divider()
        // ⌥⌘1 to ⌥⌘9 file the selected task into the first nine projects.
        Menu("Move to Project") {
          ForEach(Array(library.projects.enumerated()), id: \.element.id) { position, project in
            Button(project.title) { library.fileSelected(into: project.id) }
              .keyboardShortcut(Self.shortcut(for: position, modifiers: [.command, .option]))
          }
        }
        .disabled(library.selection == nil || library.projects.isEmpty)
        Menu("Move to View") {
          ForEach(library.views.filter { $0.id != library.currentView }, id: \.id) { view in
            Button(view.name) { library.moveSelected(toView: view.id) }
          }
        }
        .disabled(library.selection == nil || library.views.count < 2)
      }
    }
  }

  private static func shortcut(for position: Int, modifiers: EventModifiers) -> KeyboardShortcut? {
    guard position < 9, let digit = "123456789".dropFirst(position).first else { return nil }
    return KeyboardShortcut(KeyEquivalent(digit), modifiers: modifiers)
  }
}
