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
        .font(.headline)
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
          Text(
            "Moving to Dropbox copies the tasks of the Home Folder the first time. Moving back copies nothing: "
              + "the Home Folder keeps the tasks it had.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 320)
  }
}
