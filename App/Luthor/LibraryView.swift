import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The sidebar of inbox and projects next to the task list of the one selected.
struct LibraryView: View {
  @Bindable var library: LibraryViewModel
  let logURL: URL

  var body: some View {
    NavigationSplitView {
      SidebarView(library: library)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
    } detail: {
      TaskListView(library: library, logURL: logURL)
    }
  }
}

/// Inbox, then the active projects. A task dropped on a project is filed there; the field at the bottom
/// creates a project of the kind picked next to it.
private struct SidebarView: View {
  @Bindable var library: LibraryViewModel
  @State private var newProjectKind = ProjectKind.parallel

  var body: some View {
    List(selection: sidebarSelection) {
      Label("Inbox", systemImage: "tray")
        .tag(SidebarItem.inbox)
      Section("Projects") {
        ForEach(library.projects, id: \.id) { project in
          Label(project.title, systemImage: Self.symbol(for: project.kind))
            .tag(SidebarItem.project(project.id))
            .dropDestination(for: String.self) { taskIDs, _ in
              for taskID in taskIDs {
                library.file(TaskID(taskID), into: project.id)
              }
              return !taskIDs.isEmpty
            }
            .contextMenu {
              Button("Complete Project") { library.completeProject(project.id) }
            }
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      HStack(spacing: 6) {
        TextField("New project", text: $library.projectDraft)
          .textFieldStyle(.roundedBorder)
          .onSubmit { library.createProject(kind: newProjectKind) }
        Picker("Kind", selection: $newProjectKind) {
          Image(systemName: Self.symbol(for: .parallel)).help("Parallel").tag(ProjectKind.parallel)
          Image(systemName: Self.symbol(for: .sequential)).help("Sequential").tag(ProjectKind.sequential)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
      }
      .padding(8)
    }
  }

  private var sidebarSelection: Binding<SidebarItem?> {
    Binding(
      get: { library.sidebarSelection },
      set: { library.open($0 ?? .inbox) }
    )
  }

  private static func symbol(for kind: ProjectKind) -> String {
    switch kind {
    case .parallel: "list.bullet"
    case .sequential: "list.number"
    }
  }
}
