import Foundation
import LuthorDomain
import LuthorStore
import LuthorViewModels
import Testing

/// The Mac app's window as it is after a launch on the log at `url`.
@MainActor
func launchApp(on url: URL, view: ViewID = .default) -> LibraryViewModel {
  let library = LibraryViewModel(
    log: JSONLinesEventLog(fileURL: url),
    commands: Commands(deviceID: DeviceID("mac"), ids: UUIDGenerator()),
    view: view
  )
  library.reload()
  return library
}

extension LibraryViewModel {
  /// Types a title into the capture field of the list shown and presses Return.
  func capture(_ title: String) {
    draft = title
    submit()
  }

  /// Types a title into the new project field and creates the project.
  func createProject(_ title: String, kind: ProjectKind) throws -> ProjectID {
    projectDraft = title
    createProject(kind: kind)
    return try #require(projects.first { $0.title == title }).id
  }

  /// Creates a view from the view switcher; the window switches to it.
  func createView(_ name: String) throws -> ViewID {
    createView(named: name)
    return try #require(views.first { $0.name == name }).id
  }

  func task(_ title: String) throws -> TaskID {
    try #require(tasks.first { $0.title == title }).id
  }
}
