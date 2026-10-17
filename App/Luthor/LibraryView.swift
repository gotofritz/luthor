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

/// The view switcher on top, then the current view's Inbox and active projects. A task dropped on a
/// project is filed there; the field at the bottom creates a project of the kind picked next to it.
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
              Menu("Move to View") {
                ForEach(library.views.filter { $0.id != library.currentView }, id: \.id) { view in
                  Button(view.name) { library.moveProject(project.id, toView: view.id) }
                }
              }
              .disabled(library.views.count < 2)
            }
        }
      }
    }
    .safeAreaInset(edge: .top) {
      ViewSwitcher(library: library)
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

/// Shows which view the window is in; its menu switches to another view, creates one or renames this one.
private struct ViewSwitcher: View {
  private enum Naming {
    case new, rename
  }

  @Bindable var library: LibraryViewModel
  @State private var naming: Naming?
  @State private var name = ""

  var body: some View {
    Menu {
      Picker("View", selection: currentView) {
        ForEach(library.views, id: \.id) { view in
          Text(view.name).tag(view.id)
        }
      }
      .pickerStyle(.inline)
      .labelsHidden()
      Divider()
      Button("New View…") { start(.new, with: "") }
      Button("Rename View…") { start(.rename, with: currentName) }
    } label: {
      Label(currentName, systemImage: "square.stack")
        .font(.headline)
    }
    .menuStyle(.button)
    .buttonStyle(.borderless)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .alert(naming == .rename ? "Rename View" : "New View", isPresented: isNaming) {
      TextField("Name", text: $name)
      Button(naming == .rename ? "Rename" : "Create") { finish() }
      Button("Cancel", role: .cancel) {}
    }
  }

  private var currentName: String {
    library.views.first { $0.id == library.currentView }?.name ?? ""
  }

  private var currentView: Binding<ViewID> {
    Binding(get: { library.currentView }, set: { library.showView($0) })
  }

  private var isNaming: Binding<Bool> {
    Binding(get: { naming != nil }, set: { if !$0 { naming = nil } })
  }

  private func start(_ kind: Naming, with initialName: String) {
    name = initialName
    naming = kind
  }

  private func finish() {
    switch naming {
    case .new: library.createView(named: name)
    case .rename: library.renameView(library.currentView, to: name)
    case nil: break
    }
  }
}
