import Foundation
import LuthorDomain
import LuthorStore
import LuthorViewModels
import SwiftUI

/// The window: the navigation rail on the left; on the right a bar with the search box and the view
/// switcher, the capture field, the columns of the place picked and, in the projects, the new project
/// field. The capture field keeps the focus: Return captures into the inbox or the project shown, ↑ and ↓
/// select one of its tasks, ⌘Return completes it.
struct LibraryView: View {
  @Bindable var library: LibraryViewModel
  let configuration: LuthorConfiguration
  @FocusState private var captureFocused: Bool
  @State private var newProjectKind = ProjectKind.parallel

  var body: some View {
    HStack(spacing: 0) {
      NavigationRailView(library: library)
      Divider()
      VStack(spacing: 0) {
        topBar
        Divider()
        captureField
        if let message = library.errorMessage {
          Text(message)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .bottom], 12)
        }
        Divider()
        ColumnBrowserView(library: library)
        if library.section == .projects {
          Divider()
          newProjectField
        }
      }
    }
    .navigationTitle(title)
    .navigationSubtitle(configuration.location.path)
    .toolbar {
      if library.section == .projects, let projectID = shownProjectID {
        Button("Complete Project", systemImage: "checkmark.circle") { library.completeProject(projectID) }
          .help("Complete this project, its sub-projects and their open tasks")
      }
    }
    .sheet(isPresented: isDelegating) {
      DelegateSheet(library: library)
    }
    .defaultFocus($captureFocused, true)
    .onAppear { captureFocused = true }
    // Clicking a row or its checkbox would take the focus; hand it back to the capture field.
    .onChange(of: library.selection) { captureFocused = true }
    .onChange(of: library.tasks) { captureFocused = true }
    .onChange(of: library.sidebarSelection) { captureFocused = true }
    .onChange(of: library.section) { captureFocused = true }
    .task(id: configuration.location) { await watchLog() }
  }

  /// The search box, which waits for its slice, the toggle for completed items and the view switcher.
  private var topBar: some View {
    HStack(spacing: 12) {
      TextField("Search", text: .constant(""))
        .textFieldStyle(.roundedBorder)
        .disabled(true)
        .help("Search comes in a later slice")
      Toggle(isOn: $library.showCompleted) {
        Label("Completed", systemImage: "checkmark.circle")
      }
      .toggleStyle(.button)
      .help("Show completed tasks and projects")
      ViewSwitcher(library: library)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  private var captureField: some View {
    TextField("New task in \(shownProject?.title ?? "Inbox")", text: $library.draft)
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
  }

  /// Creates a project of the kind picked next to it, inside the project shown, or top-level from the inbox.
  private var newProjectField: some View {
    HStack(spacing: 6) {
      TextField(shownProjectID == nil ? "New project" : "New project in \(title)", text: $library.projectDraft)
        .textFieldStyle(.roundedBorder)
        .onSubmit { library.createProject(kind: newProjectKind) }
      Picker("Kind", selection: $newProjectKind) {
        Image(systemName: ProjectKind.parallel.symbol).help("Parallel").tag(ProjectKind.parallel)
        Image(systemName: ProjectKind.sequential.symbol).help("Sequential").tag(ProjectKind.sequential)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .fixedSize()
    }
    .padding(8)
  }

  private var isDelegating: Binding<Bool> {
    Binding(get: { library.delegatingTaskID != nil }, set: { if !$0 { library.delegatingTaskID = nil } })
  }

  private var shownProjectID: ProjectID? {
    guard case .project(let projectID) = library.sidebarSelection else { return nil }
    return projectID
  }

  private var shownProject: Project? {
    library.shownProject
  }

  private var title: String {
    switch library.section {
    case .inbox: "Inbox"
    case .today: "Today"
    case .review: "Review"
    case .projects: shownProject?.title ?? "Projects"
    case .priorities: "Prios"
    case .settings: "Settings"
    }
  }

  /// Reloads when another process or the sync service changes the log.
  private func watchLog() async {
    var monitor = configuration.makeChangeMonitor()
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(1))
      if monitor.poll() { library.reload() }
    }
  }
}

/// Shows which view the window is in; its menu switches to another view, creates one or renames this one.
/// It has no keyboard shortcuts, so it cannot be triggered by mistake.
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
    .fixedSize()
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
