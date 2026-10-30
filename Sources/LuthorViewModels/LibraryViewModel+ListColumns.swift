/// The columns each place shows, chosen from a context menu on a header. Each place keeps its own choice, and
/// the app keeps them per device through `onListColumnsChanged`; like a sort, it is only a way of showing the list
/// and writes nothing to the log.
extension LibraryViewModel {
  /// The place a list belongs to, which is what keeps the columns: every column of Projects is one place.
  func place(ofList listID: String) -> String {
    listID == "top" || listID.hasPrefix("project-") ? "projects" : listID
  }

  /// What a place shows until a header is used: everything, and the date only in Prios and Today.
  private func defaultColumns(ofPlace place: String) -> Set<ListColumn> {
    let showsWhen = place == Self.prioritiesListID || place == Self.candidatesListID
    return showsWhen ? Set(ListColumn.allCases) : Set(ListColumn.allCases).subtracting([.when])
  }

  /// Whether the place the list is in shows the column.
  public func isColumnShown(_ column: ListColumn, inList listID: String) -> Bool {
    let place = place(ofList: listID)
    return (listColumns[place] ?? defaultColumns(ofPlace: place)).contains(column)
  }

  /// Turns the column on or off for the place the list is in.
  public func toggleColumn(_ column: ListColumn, inList listID: String) {
    let place = place(ofList: listID)
    var shown = listColumns[place] ?? defaultColumns(ofPlace: place)
    if shown.contains(column) { shown.remove(column) } else { shown.insert(column) }
    listColumns[place] = shown
    onListColumnsChanged?(listColumns)
    present()
  }
}
