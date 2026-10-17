import Foundation
import LuthorDomain
import LuthorStore
import LuthorViewModels
import SwiftUI

/// The capture field on top, the open tasks of the inbox or of the project shown below. The field keeps
/// the focus: Return captures, ↑ and ↓ select a task, ⌘Return completes it. Tasks that are not next
/// actions are dimmed; drag a task onto a project in the sidebar to file it.
struct TaskListView: View {
  @Bindable var library: LibraryViewModel
  let logURL: URL
  @FocusState private var captureFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      TextField("New task", text: $library.draft)
        .textFieldStyle(.plain)
        .font(.title3)
        .padding(12)
        .focused($captureFocused)
        .onSubmit { library.submit() }
        .onKeyPress(.downArrow) {
          library.moveSelection(by: 1)
          return .handled
        }
        .onKeyPress(.upArrow) {
          library.moveSelection(by: -1)
          return .handled
        }
      if let message = library.errorMessage {
        Text(message)
          .foregroundStyle(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding([.horizontal, .bottom], 12)
      }
      Divider()
      List(selection: $library.selection) {
        ForEach(library.tasks, id: \.id) { task in
          TaskRow(task: task, isNextAction: library.nextActions.contains(task.id)) { library.complete(task.id) }
        }
      }
    }
    .navigationTitle(title)
    .navigationSubtitle(logURL.path)
    .toolbar {
      if let projectID = shownProjectID {
        Button("Complete Project", systemImage: "checkmark.circle") { library.completeProject(projectID) }
          .help("Complete this project and its open tasks")
      }
    }
    .defaultFocus($captureFocused, true)
    .onAppear { captureFocused = true }
    // Clicking a row or its checkbox would take the focus; hand it back to the capture field.
    .onChange(of: library.selection) { captureFocused = true }
    .onChange(of: library.tasks) { captureFocused = true }
    .onChange(of: library.sidebarSelection) { captureFocused = true }
    .task { await watchLog() }
  }

  private var shownProjectID: ProjectID? {
    guard case .project(let projectID) = library.sidebarSelection else { return nil }
    return projectID
  }

  private var title: String {
    library.projects.first { $0.id == shownProjectID }?.title ?? "Inbox"
  }

  /// Reloads when another process, such as the CLI, changes the log.
  private func watchLog() async {
    var monitor = FileChangeMonitor(fileURL: logURL)
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(1))
      if monitor.poll() { library.reload() }
    }
  }
}

private struct TaskRow: View {
  let task: TaskItem
  let isNextAction: Bool
  let complete: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Button(action: complete) {
        Image(systemName: "circle")
      }
      .buttonStyle(.plain)
      .help("Complete")
      Text(task.title)
        .foregroundStyle(isNextAction ? .primary : .secondary)
    }
    .tag(task.id)
    .draggable(task.id.rawValue)
  }
}
