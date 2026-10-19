import AppKit
import Foundation
import LuthorDomain
import LuthorStore
import LuthorViewModels
import SwiftUI

/// The log of a window that has not yet been told where the tasks live: the first-start modal covers it.
private struct NoEventLog: EventLog {
  func readAll() throws(EventLogError) -> [EventEnvelope] { [] }
  func append(_ events: [EventEnvelope]) throws(EventLogError) {
    throw .ioFailure("no place for the log has been chosen")
  }
}

@main
struct LuthorApp: App {
  /// The `UserDefaults` key of the view shown last; per device, so it stays out of the log.
  private static let lastViewKey = "lastViewID"
  /// The `UserDefaults` keys of the place chosen for the log, per device, so they stay out of the log too.
  private static let storageKindKey = "logStorageKind"
  private static let storageFolderKey = "logStorageDropboxFolder"
  /// The `UserDefaults` key of this Mac's own ID, made on first start; it names this Mac's file in the shared
  /// folder, since two Macs can have the same host name.
  private static let machineIDKey = "machineID"

  private let home = FileManager.default.homeDirectoryForCurrentUser
  private let environment: [String: String]
  @State private var storageController: StorageController
  @State private var configuration: LuthorConfiguration
  @State private var library: LibraryViewModel

  init() {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let environment = Self.environment()
    let saved = LogStorage(
      kindName: UserDefaults.standard.string(forKey: Self.storageKindKey),
      dropboxFolderPath: UserDefaults.standard.string(forKey: Self.storageFolderKey), home: home)
    // The device ID is the same wherever the log lives; Dropbox needs it to name this Mac's file.
    let deviceID = LuthorConfiguration(
      environment: environment, home: home, machineID: Self.machineID(),
      storage: LogStorage(kind: .dropbox, dropboxFolder: LogStorage.defaultDropboxFolder(home: home))
    ).deviceID
    let controller = StorageController(
      saved: saved, home: home, deviceID: deviceID,
      lockedByEnvironment: LuthorConfiguration.environmentSetsLocation(environment)
    ) { choice in
      UserDefaults.standard.set(choice.kindName, forKey: Self.storageKindKey)
      UserDefaults.standard.set(choice.dropboxFolder.path, forKey: Self.storageFolderKey)
    }
    let configuration = LuthorConfiguration(
      environment: environment, home: home, machineID: Self.machineID(), storage: saved)
    self.environment = environment
    _storageController = State(initialValue: controller)
    _configuration = State(initialValue: configuration)
    _library = State(
      initialValue: Self.makeLibrary(
        log: controller.needsSetup ? NoEventLog() : configuration.makeEventLog(),
        deviceID: configuration.deviceID,
        view: UserDefaults.standard.string(forKey: Self.lastViewKey).map(ViewID.init) ?? .default))
  }

  /// Gives the running app its icon explicitly. ⌘-Tab and the Dock show the icon of the running process, and
  /// Launch Services can keep serving the generic one it cached before the app had an icon.
  private static func setApplicationIcon() {
    if let icon = NSImage(named: "AppIcon") {
      NSApplication.shared.applicationIconImage = icon
    }
  }

  /// The process environment, with the device name a Mac app started from the Finder cannot get from a
  /// shell read from the app's defaults instead: `defaults write com.gotofritz.luthor LUTHOR_DEVICE_ID desk`.
  private static func environment() -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    if environment["LUTHOR_DEVICE_ID"] == nil {
      environment["LUTHOR_DEVICE_ID"] = UserDefaults.standard.string(forKey: "LUTHOR_DEVICE_ID")
    }
    return environment
  }

  /// The ID of this Mac, made on first start and kept in the app's defaults, which are not synced.
  private static func machineID() -> String {
    MachineID.current(
      saved: UserDefaults.standard.string(forKey: machineIDKey), make: { UUID().uuidString },
      save: { UserDefaults.standard.set($0, forKey: machineIDKey) })
  }

  private static func makeLibrary(log: any EventLog, deviceID: DeviceID, view: ViewID) -> LibraryViewModel {
    let library = LibraryViewModel(
      log: log, commands: Commands(deviceID: deviceID, ids: UUIDGenerator()), view: view)
    library.reload()
    return library
  }

  /// Opens the log in the place now chosen, staying in the view shown.
  private func openChosenPlace() {
    let configuration = LuthorConfiguration(
      environment: environment, home: home, machineID: Self.machineID(), storage: storageController.storage)
    self.configuration = configuration
    library = Self.makeLibrary(
      log: configuration.makeEventLog(), deviceID: configuration.deviceID, view: library.currentView)
  }

  /// Saves the whole log as a YAML file the user names.
  private func exportToText() {
    guard let text = library.exportText() else { return }
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "luthor.yml"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      try text.write(to: url, atomically: true, encoding: .utf8)
    } catch {
      NSAlert(error: error).runModal()
    }
  }

  /// Adds the events of a YAML export the user picks that the log does not have yet.
  private func importFromText() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
      library.importText(try String(contentsOf: url, encoding: .utf8))
    } catch {
      NSAlert(error: error).runModal()
    }
  }

  var body: some Scene {
    Window("Luthor", id: "library") {
      LibraryView(library: library, configuration: configuration)
        .themed(library.viewSettings.themeAccent)
        .onAppear { Self.setApplicationIcon() }
        .environment(storageController)
        .sheet(isPresented: .constant(storageController.needsSetup)) {
          StorageSetupSheet(controller: storageController)
        }
        .onChange(of: storageController.storage) { openChosenPlace() }
        .onChange(of: library.currentView, initial: true) { _, view in
          UserDefaults.standard.set(view.rawValue, forKey: Self.lastViewKey)
        }
    }
    .defaultSize(width: 760, height: 640)
    .commands {
      CommandGroup(replacing: .importExport) {
        Button("Export to Text…") { exportToText() }
        Button("Import from Text…") { importFromText() }
      }
      CommandGroup(replacing: .appSettings) {
        Button("Settings…") { library.show(.settings) }
          .keyboardShortcut(",", modifiers: .command)
      }
      CommandMenu("Task") {
        Button("Complete") { library.completeSelected() }
          .keyboardShortcut(.return, modifiers: .command)
          .disabled(library.selection == nil)
        Menu("Priority") {
          ForEach(Priority.allCases, id: \.self) { priority in
            Button(priority.title, systemImage: priority.symbol) { library.prioritizeSelected(as: priority) }
          }
          Divider()
          Button("None") { library.prioritizeSelected(as: nil) }
        }
        .disabled(library.selection == nil)
        Menu("Estimate") {
          ForEach([5, 15, 30, 60], id: \.self) { minutes in
            Button("\(minutes)m") { library.estimateSelected(as: minutes) }
          }
          Divider()
          Button("None") { library.estimateSelected(as: nil) }
        }
        .disabled(library.selection == nil)
        Button("Duplicate") { library.duplicateSelected() }
          .keyboardShortcut("d", modifiers: [.command, .shift])
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
      CommandMenu("Plan") {
        Button("Show Today") {
          library.show(.today)
          library.showToday()
        }
        .keyboardShortcut("t", modifiers: [.command, .shift])
        Button("Show Calendar") { library.show(.calendar) }
          .keyboardShortcut("c", modifiers: [.command, .shift])
        Button("Show Day Review") { library.show(.review) }
          .keyboardShortcut("n", modifiers: [.command, .shift])
        Button("Show Project Reviews") { library.show(.weeklyReview) }
        Button("Mark Project Reviewed") { library.markProjectReviewed() }
          .keyboardShortcut("r", modifiers: [.command, .shift])
          .disabled(library.section != .weeklyReview || library.reviewProjectID == nil)
        Button("Previous Day") { library.showPreviousDay() }
          .keyboardShortcut("[", modifiers: .command)
        Button("Next Day") { library.showNextDay() }
          .keyboardShortcut("]", modifiers: .command)
        Divider()
        Button("Add to Plan") { library.addSelectedToPlan() }
          .keyboardShortcut("t", modifiers: .command)
        Button("Remove from Plan") { library.removeSelectedFromPlan() }
          .keyboardShortcut("t", modifiers: [.command, .option])
        Button("Move Earlier") { library.moveSelectedInPlan(by: -1) }
          .keyboardShortcut(.upArrow, modifiers: [.command, .option])
        Button("Move Later") { library.moveSelectedInPlan(by: 1) }
          .keyboardShortcut(.downArrow, modifiers: [.command, .option])
        Divider()
        Button("Defer to Tomorrow") { library.deferSelected() }
          .keyboardShortcut("d", modifiers: .command)
        Button("Delegate…") { library.delegatingTaskID = library.selection }
          .keyboardShortcut("l", modifiers: .command)
        Button("Send to Someday") { library.sendSelectedToSomeday() }
          .keyboardShortcut("y", modifiers: .command)
        Button("Skip This One") { library.skipSelected() }
          .disabled(library.selection.flatMap { library.repeatRule(of: $0) } == nil)
        Button("Drop Task") { library.dropSelected() }
          .keyboardShortcut(.delete, modifiers: [.command, .shift])
      }
    }
  }

  private static func shortcut(for position: Int, modifiers: EventModifiers) -> KeyboardShortcut? {
    guard position < 9, let digit = "123456789".dropFirst(position).first else { return nil }
    return KeyboardShortcut(KeyEquivalent(digit), modifiers: modifiers)
  }
}
