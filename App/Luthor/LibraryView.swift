import Foundation
import LuthorDomain
import LuthorStore
import LuthorViewModels
import SwiftUI

/// The window: the navigation rail on the left; on the right a bar with the search box and the view
/// switcher, the capture field and the columns of the place picked. The capture field keeps the focus: Return
/// captures into the inbox or the project shown, ↑ and ↓ select one of its tasks, ⌘Return completes it. In the
/// projects there is no capture field: each column has a plus button that adds to it.
struct LibraryView: View {
  @Bindable var library: LibraryViewModel
  let configuration: LuthorConfiguration
  @FocusState private var captureFocused: Bool
  @Environment(\.theme) private var theme

  var body: some View {
    HStack(spacing: 0) {
      NavigationRailView(library: library)
      Divider()
      VStack(spacing: 0) {
        header
        topBar
        Divider()
        if library.section != .projects {
          captureField
        }
        if let message = library.errorMessage {
          Text(message)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.horizontal, .bottom], 12)
        }
        Divider()
        ColumnBrowserView(library: library)
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

  /// The view's name in small spaced capitals, the place shown in large heavy type and a rule in the view's
  /// accent, so the window says at a glance which view it is.
  private var header: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(currentViewName.uppercased())
        .font(Theme.label)
        .tracking(1.5)
        .foregroundStyle(theme.ink)
      Text(title)
        .font(Theme.display)
        .tracking(-0.5)
        .lineLimit(1)
      Rectangle()
        .fill(theme.fill)
        .frame(height: 3)
        .padding(.top, 6)
    }
    .padding(.horizontal, 12)
    .padding(.top, 12)
  }

  private var currentViewName: String {
    library.views.first { $0.id == library.currentView }?.name ?? ""
  }

  /// The search box, which waits for its slice, the toggle for completed and dropped items and the view switcher.
  private var topBar: some View {
    HStack(spacing: 12) {
      TextField("Search", text: .constant(""))
        .textFieldStyle(.roundedBorder)
        .disabled(true)
        .help("Search comes in a later slice")
      Toggle(isOn: $library.showCompleted) {
        Label("Completed and dropped", systemImage: "checkmark.circle")
      }
      .toggleStyle(.button)
      .help("Show completed and dropped tasks and projects")
      ViewSwitcher(library: library)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  private var captureField: some View {
    TextField("New task in \(captureTarget)", text: $library.draft)
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

  private var isDelegating: Binding<Bool> {
    Binding(get: { library.delegatingTaskID != nil }, set: { if !$0 { library.delegatingTaskID = nil } })
  }

  private var shownProjectID: TaskID? {
    guard case .project(let projectID) = library.sidebarSelection else { return nil }
    return projectID
  }

  private var shownProject: Project? {
    library.shownProject
  }

  /// Where a captured task goes: the project the weekly review has picked, the project shown, or the inbox.
  private var captureTarget: String {
    if library.section == .weeklyReview {
      return library.projectReview.first { $0.project.id == library.reviewProjectID }?.project.title ?? "Inbox"
    }
    return shownProject?.title ?? "Inbox"
  }

  private var title: String {
    switch library.section {
    case .inbox: "Inbox"
    case .today: "Today"
    case .calendar: "Calendar"
    case .review: "Review"
    case .weeklyReview: "Reviews"
    case .projects: shownProject?.title ?? "Projects"
    case .priorities: "Prios"
    case .tags: "Tags"
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
        .font(Theme.section)
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
