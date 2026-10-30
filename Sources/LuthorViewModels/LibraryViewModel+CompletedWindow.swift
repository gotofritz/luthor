import LuthorDomain

/// How far back the completed tasks of each place reach. Each place keeps its own, like its columns; the
/// setting only applies while completed items are shown.
extension LibraryViewModel {
  /// The list whose header sets what the place shown lists: the columns of Projects have one between them.
  var shownListID: String {
    section == .projects ? "top" : taskListID
  }

  /// The stretch of days the place the list is in lists completed items for; every one until it is narrowed.
  public func completedWindow(ofList listID: String) -> CompletedWindow {
    completedWindows[place(ofList: listID)] ?? .all
  }

  /// Narrows or widens the completed items listed in the place the list is in.
  public func setCompletedWindow(_ window: CompletedWindow, ofList listID: String) {
    completedWindows[place(ofList: listID)] = window == .all ? nil : window
    present()
  }
}
