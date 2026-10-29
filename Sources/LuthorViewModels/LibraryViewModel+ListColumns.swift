/// The columns each list shows, chosen from a context menu on its header. Each list keeps its own choice while
/// the window is open; like a sort, it is only a way of showing the list and writes nothing to the log.
extension LibraryViewModel {
  /// What a list shows until its header is used: everything, and the date only in Prios and Today.
  private func defaultColumns(ofList listID: String) -> Set<ListColumn> {
    let showsWhen = listID == Self.prioritiesListID || listID == Self.candidatesListID
    return showsWhen ? Set(ListColumn.allCases) : Set(ListColumn.allCases).subtracting([.when])
  }

  /// Whether the list shows the column.
  public func isColumnShown(_ column: ListColumn, inList listID: String) -> Bool {
    (listColumns[listID] ?? defaultColumns(ofList: listID)).contains(column)
  }

  /// Turns the column of the list on or off.
  public func toggleColumn(_ column: ListColumn, inList listID: String) {
    var shown = listColumns[listID] ?? defaultColumns(ofList: listID)
    if shown.contains(column) { shown.remove(column) } else { shown.insert(column) }
    listColumns[listID] = shown
    present()
  }
}
