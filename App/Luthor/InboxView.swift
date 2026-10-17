import Foundation
import LuthorDomain
import LuthorStore
import LuthorViewModels
import SwiftUI

/// The capture field on top, open tasks below. The field keeps the focus: Return captures, ↑ and ↓
/// select a task, ⌘Return completes it.
struct InboxView: View {
  @Bindable var inbox: LibraryViewModel
  let logURL: URL
  @FocusState private var captureFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      TextField("New task", text: $inbox.draft)
        .textFieldStyle(.plain)
        .font(.title3)
        .padding(12)
        .focused($captureFocused)
        .onSubmit { inbox.submit() }
        .onKeyPress(.downArrow) {
          inbox.moveSelection(by: 1)
          return .handled
        }
        .onKeyPress(.upArrow) {
          inbox.moveSelection(by: -1)
          return .handled
        }
      if let message = inbox.errorMessage {
        Text(message)
          .foregroundStyle(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding([.horizontal, .bottom], 12)
      }
      Divider()
      List(selection: $inbox.selection) {
        ForEach(inbox.tasks, id: \.id) { task in
          TaskRow(task: task) { inbox.complete(task.id) }
        }
      }
    }
    .navigationTitle("Inbox")
    .navigationSubtitle(logURL.path)
    .defaultFocus($captureFocused, true)
    .onAppear { captureFocused = true }
    // Clicking a row or its checkbox would take the focus; hand it back to the capture field.
    .onChange(of: inbox.selection) { captureFocused = true }
    .onChange(of: inbox.tasks) { captureFocused = true }
    .task { await watchLog() }
  }

  /// Reloads when another process, such as the CLI, changes the log.
  private func watchLog() async {
    var monitor = FileChangeMonitor(fileURL: logURL)
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(1))
      if monitor.poll() { inbox.reload() }
    }
  }
}

private struct TaskRow: View {
  let task: TaskItem
  let complete: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Button(action: complete) {
        Image(systemName: "circle")
      }
      .buttonStyle(.plain)
      .help("Complete")
      Text(task.title)
    }
    .tag(task.id)
  }
}
