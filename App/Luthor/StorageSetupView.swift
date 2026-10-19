import LuthorStore
import LuthorViewModels
import SwiftUI

/// The radio buttons that choose where the log lives, and the Dropbox folder.
struct StorageChoiceForm: View {
  @Bindable var controller: StorageController

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Picker("Keep the tasks in", selection: $controller.kind) {
        Text("Dropbox").tag(LogStorage.Kind.dropbox)
        Text("Home Folder").tag(LogStorage.Kind.homeFolder)
      }
      .pickerStyle(.radioGroup)
      switch controller.kind {
      case .dropbox:
        TextField("Folder", text: $controller.dropboxFolderPath)
          .textFieldStyle(.roundedBorder)
        Text("The same tasks on every Mac that uses this folder. Dropbox does the syncing.")
          .font(.caption)
          .foregroundStyle(.secondary)
      case .homeFolder:
        Text("~/.luthor/events.jsonl, on this Mac only.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if let message = controller.errorMessage {
        Text(message).foregroundStyle(.red)
      }
    }
  }
}

/// The modal shown at the first start, until the user has chosen where the log lives.
struct StorageSetupSheet: View {
  @Bindable var controller: StorageController

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Where should Luthor keep your tasks?")
        .font(Theme.section)
      StorageChoiceForm(controller: controller)
      HStack {
        Spacer()
        Button("Continue") { controller.confirm() }
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 420)
    .interactiveDismissDisabled()
  }
}

/// The "This Mac" settings: the place of the log, changed here after the first start.
struct ThisMacSettingsColumn: View {
  @Environment(StorageController.self) private var controller
  @State private var confirmingCompaction = false

  private static let movingNote = """
    Moving to Dropbox copies the tasks of the Home Folder the first time. \
    Moving back copies nothing: the Home Folder keeps the tasks it had.
    """

  private static let compactNote = """
    Rebuilds the log with one short run of events for each task and project, which makes it small again. \
    Time logged and reviewed days are dropped; tasks, projects, settings and project reviews stay. \
    The old log and a YAML copy are kept in a backups folder next to it. Close Luthor on your other Macs \
    and let Dropbox finish first.
    """

  var body: some View {
    Form {
      Section("Storage") {
        if controller.lockedByEnvironment {
          Text("The place of the log is set by LUTHOR_LOG or LUTHOR_SYNC_DIR in the environment.")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          StorageChoiceForm(controller: controller)
          Button("Use This Place") { controller.confirm() }
          Text(Self.movingNote)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Section("Log size") {
        Button("Compact Log…") { confirmingCompaction = true }
        Text(Self.compactNote)
          .font(.caption)
          .foregroundStyle(.secondary)
        if let message = controller.compactionMessage {
          Text(message)
            .font(.caption)
        }
      }
    }
    .confirmationDialog("Compact the log?", isPresented: $confirmingCompaction) {
      Button("Compact Log") { controller.compactLog() }
    } message: {
      Text(Self.compactNote)
    }
    .formStyle(.grouped)
    .frame(width: 320)
  }
}
