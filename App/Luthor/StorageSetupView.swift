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
      if let message = controller.folderWarning {
        Text(message).font(.caption).foregroundStyle(.orange)
      } else if case .inDropbox(let root) = controller.folderStatus {
        Text("Syncing through the Dropbox folder \(root.path).").font(.caption).foregroundStyle(.secondary)
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
  let library: LibraryViewModel
  @State private var confirmingCompaction = false
  @State private var confirmingForce = false
  @State private var confirmingCancel = false

  private static let movingNote = """
    Moving to Dropbox copies the tasks of the Home Folder the first time. \
    Moving back copies nothing: the Home Folder keeps the tasks it had.
    """

  private static let datingNote = """
    Completed tasks ticked before the day was kept have none, so only the Completed Tasks choice All lists them. \
    This gives each the day it was due, else the day it was planned for, else three days ago. \
    It only adds to the log and is meant to be run once; run it again after Compact Log.
    """

  private static let compactNote = """
    Rebuilds the log with one short run of events for each task and project, which makes it small again. \
    Time logged and reviewed days are dropped; tasks, projects, settings and project reviews stay. \
    The old log and a YAML copy are kept in a backups folder next to it. With Dropbox, the other Macs are \
    asked to stop writing first and this Mac waits for them.
    """

  private static let forceNote = """
    A Mac that has not answered may have changes that have not reached Dropbox. Compacting now keeps what \
    this Mac can see; those changes are applied on top when they arrive, but some may be overridden.
    """

  /// What the button row shows depends on how far the handshake with the other Macs has got.
  @ViewBuilder private var compactionControls: some View {
    switch controller.compactionProgress {
    case .idle:
      Button("Compact Log…") { confirmingCompaction = true }
    case .waiting(let devices):
      Text("Waiting for \(devices.joined(separator: ", ")) to stop writing and finish syncing. Open Luthor there.")
        .font(.caption)
      Button("Compact Anyway…") { confirmingForce = true }
      Button("Cancel") { controller.cancelCompaction() }
    case .ready:
      Text("Every other Mac has stopped writing and its changes have arrived.")
        .font(.caption)
      Button("Compact Now") { controller.finishCompaction() }
      Button("Cancel") { controller.cancelCompaction() }
    case .pausedForOther(let device):
      Text("\(device) is compacting the log. This Mac waits until it is done, or ten minutes.")
        .font(.caption)
      Button("Cancel Their Compaction…") { confirmingCancel = true }
    }
  }

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
      Section("Completed tasks") {
        Button("Date Old Completions") { library.dateOldCompletions() }
        Text(Self.datingNote)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section("Log size") {
        compactionControls
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
      Button("Compact Log") { controller.startCompaction() }
    } message: {
      Text(Self.compactNote)
    }
    .confirmationDialog("Cancel the other Mac's compaction?", isPresented: $confirmingCancel) {
      Button("Cancel Compaction", role: .destructive) { controller.cancelCompaction() }
    } message: {
      Text(
        """
        Only do this if that Mac is not compacting any more, for example because it was quit. \
        This Mac writes again.
        """)
    }
    .confirmationDialog("Compact without waiting?", isPresented: $confirmingForce) {
      Button("Compact Anyway", role: .destructive) { controller.finishCompaction(force: true) }
    } message: {
      Text(Self.forceNote)
    }
    .formStyle(.grouped)
    .frame(width: 320)
  }
}
