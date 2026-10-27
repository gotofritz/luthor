extension Commands {
  /// The events that add what an export holds and the library does not have yet. An item, view or tag that
  /// exists is left as it is, so importing a file twice changes nothing, and a file from another Mac merges.
  /// Items are captured, given their fields while open, and only then completed or dropped, so a project
  /// that took its items along when it was finished does so again. The events count on from the Lamport counter
  /// of `log`, or from `lamport` if that is higher, so they outrank any older events that turn up later.
  public func importLibrary(
    _ export: LibraryExport, log: [EventEnvelope], startingAfter lamport: UInt64 = 0
  ) throws(CommandError) -> [EventEnvelope] {
    let state = libraryState(from: log)
    var writer = ImportWriter(commands: self, after: max(lamport, lastLamport(of: log)))
    writer.addViews(of: export, to: state, renaming: log.isEmpty)
    let knownTags = Set(state.tagItems.map(\.id))
    for tag in export.tags where !knownTags.contains(tag.id) {
      writer.add(.tagCreated(TagCreated(tagID: tag.id, name: tag.name, viewID: tag.view)))
    }
    for setting in export.settings ?? [] {
      guard let key = SettingKey(rawValue: setting.key) else { continue }
      let existing: String? =
        if let view = setting.view { state.viewSettingOverrides[view]?[key] } else { state.globalSettingValues[key] }
      if existing == nil {
        writer.add(.settingChanged(SettingChanged(key: key, value: setting.value, viewID: setting.view)))
      }
    }
    if let days = export.reviewDefault, state.defaultReviewInterval == .weekly {
      writer.add(.reviewDefaultSet(ReviewDefaultSet(interval: ReviewInterval(days: days))))
    }
    let known = export.items.filter { state.items[$0.id] == nil }
    let viewIDs = Set(state.views.map(\.id) + export.views.map(\.id))
    if let missing = known.first(where: { !viewIDs.contains($0.view) }) { throw .noView(missing.view) }
    for item in known { writer.addFields(of: item) }
    // Children before their parent: a project finished first would take along an item that was finished
    // on its own.
    for item in known.reversed() where item.status != .open && item.finishedWith == nil {
      let id = item.id
      writer.add(
        item.status == .completed
          ? .taskCompleted(TaskCompleted(taskID: id)) : .taskDropped(TaskDropped(taskID: id)))
    }
    return writer.events
  }
}

/// Collects the events of an import with ids and Lamport counters that continue the log.
private struct ImportWriter {
  let commands: Commands
  var next: UInt64
  private(set) var events: [EventEnvelope] = []

  init(commands: Commands, after lamport: UInt64) {
    self.commands = commands
    next = lamport + 1
  }

  mutating func add(_ payload: EventPayload) {
    events.append(
      EventEnvelope(
        id: EventID(commands.ids.next()), deviceID: commands.deviceID, lamport: next, payload: payload))
    next += 1
  }

  /// Creates the views the library lacks. With `renaming`, a view it has under another name takes the
  /// export's: an empty library has only the default view, which the export may have renamed.
  mutating func addViews(of export: LibraryExport, to state: LibraryState, renaming: Bool) {
    for view in export.views {
      if let known = state.views.first(where: { $0.id == view.id }) {
        if renaming && known.name != view.name { add(.viewRenamed(ViewRenamed(viewID: view.id, name: view.name))) }
      } else {
        add(.viewCreated(ViewCreated(viewID: view.id, name: view.name)))
      }
    }
  }

  /// Captures the item and sets what it has while it is still open.
  mutating func addFields(of item: ExportedItem) {
    let id = item.id
    add(
      .taskCaptured(
        TaskCaptured(
          taskID: id, title: item.title, viewID: item.view, createdOn: item.createdOn, parentID: item.parent,
          kind: item.kind)))
    if let notes = item.notes { add(.taskNoted(TaskNoted(taskID: id, notes: notes))) }
    if let priority = item.priority { add(.taskPrioritized(TaskPrioritized(taskID: id, priority: priority))) }
    if let minutes = item.estimate { add(.taskEstimated(TaskEstimated(taskID: id, minutes: minutes))) }
    for tag in item.tags ?? [] { add(.taskTagged(TaskTagged(taskID: id, tagID: tag))) }
    if let day = item.scheduled { add(.taskScheduled(TaskScheduled(taskID: id, date: day))) }
    if let due = item.due { add(.taskDueSet(TaskDueSet(taskID: id, date: due.date, isHard: due.hard))) }
    if let rule = item.repeatRule { add(.taskRepeatSet(TaskRepeatSet(taskID: id, rule: rule))) }
    addReviewFields(of: item)
    if let handed = item.delegated {
      add(
        .taskDelegated(
          TaskDelegated(taskID: id, to: handed.person, since: handed.since, followUpDate: handed.followUp)))
    }
  }

  /// Sets the item's weekly review: interval, last review and chosen next review.
  mutating func addReviewFields(of item: ExportedItem) {
    let id = item.id
    if let days = item.reviewEvery {
      add(.reviewIntervalSet(ReviewIntervalSet(taskID: id, interval: ReviewInterval(days: days))))
    }
    if let day = item.reviewedOn { add(.taskReviewed(TaskReviewed(taskID: id, date: day))) }
    if let day = item.reviewNext { add(.reviewDateSet(ReviewDateSet(taskID: id, date: day))) }
  }
}
