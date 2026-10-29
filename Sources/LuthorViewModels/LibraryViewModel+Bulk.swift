import LuthorDomain

// Several tasks selected together (shift- and command-click): one card edits them all, and tagging, dropping
// and deleting apply to each. A command is one undo step however many tasks it touches.
extension LibraryViewModel {
  /// The tasks selected: the several picked together, else the single one selected.
  public var selectedIDs: Set<TaskID> {
    multiSelection.isEmpty ? selection.map { [$0] } ?? [] : multiSelection
  }

  /// Whether more than one task is selected, so the card edits them together.
  public var isBulkSelection: Bool { multiSelection.count > 1 }

  /// Selects exactly these tasks, as the list reports a click, a shift-click or a command-click. One task is
  /// the ordinary selection; none clears it.
  public func setSelection(_ ids: Set<TaskID>) {
    if ids.count > 1 {
      multiSelection = ids
      selection = nil
    } else {
      multiSelection = []
      selection = ids.first
    }
  }

  /// The fields of the tasks selected together, shown only where all agree; `nil` unless there are two or more.
  public var bulkCard: BulkSummary? {
    _ = revision
    guard isBulkSelection else { return nil }
    let summary = state.bulkSummary(of: orderedSelection)
    return summary.count > 1 ? summary : nil
  }

  /// Applies what the bulk card sets to every task selected, as one step to undo.
  public func applyBulk(_ edit: BulkEdit) {
    let ids = orderedSelection
    perform { (log) throws(CommandError) in try commands.bulkEdit(edit, taskIDs: ids, log: log) }
  }

  /// Puts the tag called `name` on every selected task, creating it in the view if it has none of that name.
  public func tagSelected(named name: String) {
    applyBulk(BulkEdit(addTags: [name]))
  }

  /// Takes a tag off every selected task that carries it.
  public func untagSelected(_ tagID: TagID) {
    applyBulk(BulkEdit(removeTags: [tagID]))
  }

  /// Drops every selected task.
  public func dropSelectedTasks() {
    let ids = orderedSelection
    perform { (log) throws(CommandError) in try commands.drop(taskIDs: ids, log: log) }
  }

  /// Deletes every selected task for good.
  public func deleteSelectedTasks() {
    let ids = orderedSelection
    perform { (log) throws(CommandError) in try commands.delete(taskIDs: ids, log: log) }
  }

  /// The selected tasks in the order of the list, those it does not show last, so a command is the same each time.
  private var orderedSelection: [TaskID] {
    let chosen = selectedIDs
    let listed = tasks.map(\.id).filter(chosen.contains)
    return listed + chosen.subtracting(listed).sorted { $0.rawValue < $1.rawValue }
  }

  /// Leaves out of the bulk selection the tasks that are no longer open.
  func pruneMultiSelection() {
    guard !multiSelection.isEmpty else { return }
    let open = Set(state.bulkSummary(of: Array(multiSelection)).taskIDs)
    let kept = multiSelection.intersection(open)
    if kept != multiSelection { setSelection(kept) }
  }
}
