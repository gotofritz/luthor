import Foundation
import LuthorDomain
import LuthorStore
import LuthorTestSupport
import LuthorViewModels
import Testing

/// The Mac app's window as it is after a launch on the log at `url`, on a day that is `today` (by default
/// a Monday).
@MainActor
func launchApp(on url: URL, view: ViewID = .default, today: CalendarDate = date("2026-10-19")) -> LibraryViewModel {
  launchApp(log: JSONLinesEventLog(fileURL: url), device: "mac", view: view, today: today)
}

/// The Mac app of the device `device`, working in the shared folder `folder`, as when the folder is synced
/// by Dropbox.
@MainActor
func launchApp(
  sharing folder: URL, as device: String, view: ViewID = .default, today: CalendarDate = date("2026-10-19")
) -> LibraryViewModel {
  launchApp(
    log: DeviceFilesEventLog(directory: folder, deviceID: DeviceID(device)), device: device, view: view,
    today: today)
}

/// The Mac app as it opens with `configuration`, the way `LuthorApp` builds it.
@MainActor
func launchApp(configuration: LuthorConfiguration, view: ViewID = .default) -> LibraryViewModel {
  launchApp(
    log: configuration.makeEventLog(), device: configuration.deviceID.rawValue, view: view,
    today: date("2026-10-19"))
}

@MainActor
private func launchApp(
  log: any EventLog, device: String, view: ViewID, today: CalendarDate
) -> LibraryViewModel {
  let library = LibraryViewModel(
    log: log,
    commands: Commands(deviceID: DeviceID(device), ids: UUIDGenerator()),
    view: view,
    today: { today }
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
  func createProject(_ title: String, kind: ProjectKind) throws -> TaskID {
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
