import LuthorDomain

// Tags: the Tags place, putting tags on tasks, and narrowing Today's candidates. In its own file (SwiftLint
// file_length) rather than suppressed.
extension LibraryViewModel {
  /// Picks a tag in the Tags place, which lists its tasks, with no task selected.
  public func showTag(_ tagID: TagID?) {
    selectedTagID = tagID
    selection = nil
    editingCard = nil
    newItem = nil
    present()
  }

  /// The tags a task carries, in the order they were created.
  public func tagItems(of taskID: TaskID) -> [TagItem] {
    _ = revision
    return state.tags(of: taskID)
  }

  /// Puts the tag called `name` on a task, creating it in the task's view if the view has none of that name.
  public func tagTask(_ taskID: TaskID, named name: String) {
    perform { (log) throws(CommandError) in try commands.tag(taskID: taskID, named: name, log: log) }
  }

  /// Makes the tags of a task exactly the ones called `names`, creating those its view lacks.
  public func setTags(_ taskID: TaskID, to names: [String]) {
    perform { (log) throws(CommandError) in try commands.setTags(taskID: taskID, to: names, log: log) }
  }

  /// Puts a tag on a task, or takes it off if the task carries it.
  public func toggleTag(_ tagID: TagID, on taskID: TaskID) {
    perform { (log) throws(CommandError) in
      let carried = state.tags(of: taskID).contains { $0.id == tagID }
      if carried {
        return try commands.untag(taskID: taskID, from: tagID, log: log)
      }
      return try commands.tag(taskID: taskID, with: tagID, log: log)
    }
  }

  /// How many tasks carry a tag, open or completed.
  public func tagUseCount(_ tagID: TagID) -> Int {
    _ = revision
    return state.tagUseCount(of: tagID)
  }

  /// Deletes a tag, which takes it off its tasks. A narrowing of Today's candidates to it is dropped.
  public func removeTag(_ tagID: TagID) {
    var filter = candidateFilter
    if filter.tags.remove(tagID) != nil { candidateFilter = filter }
    perform { (log) throws(CommandError) in try commands.deleteTag(tagID, log: log) }
  }

  /// Narrows Today's candidates to the tasks that carry the tag too, or if they are narrowed to it, drops it.
  public func toggleCandidateTag(_ tagID: TagID) {
    var filter = candidateFilter
    if !filter.tags.insert(tagID).inserted { filter.tags.remove(tagID) }
    candidateFilter = filter
  }

  /// Fills the view's tags with their counts, and drops a tag picked in another view.
  func presentTags() {
    tags = state.tags(in: currentView)
    if let picked = selectedTagID, !tags.contains(where: { $0.id == picked }) { selectedTagID = nil }
    if section == .tags { tagTaskCounts = state.taskCounts(ofTagsIn: currentView) }
  }
}
