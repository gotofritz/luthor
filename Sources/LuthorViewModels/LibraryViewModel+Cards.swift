import LuthorDomain

/// Editing a card: it is read-only until Edit, and OK or Cancel ends the edit.
extension LibraryViewModel {
  /// Puts a card into edit mode. The card of something completed stays read-only.
  public func editCard(_ card: CardTarget) {
    let isCompleted =
      switch card {
      case .task(let taskID): completedTaskIDs.contains(taskID)
      case .project(let projectID): completedProjectIDs.contains(projectID)
      }
    if !isCompleted { editingCard = card }
  }

  /// A project's estimate as its card shows it: its own, else the sum of its open tasks' estimates; `nil` if
  /// there is none. It is shown and never planned.
  public func rolledUpEstimate(of projectID: TaskID) -> Int? {
    state.rolledUpEstimate(of: projectID)
  }

  /// Leaves edit mode and drops what was typed.
  public func cancelCardEdit() {
    editingCard = nil
  }

  /// Keeps what was typed on a task's card and leaves edit mode. A blank title keeps the card in edit mode
  /// and writes nothing.
  public func saveCard(ofTask taskID: TaskID, _ draft: TaskCardDraft) {
    guard !draft.title.allSatisfy(\.isWhitespace) else { return }
    perform { (log) throws(CommandError) in try cardEvents(of: taskID, draft, log: log) }
    if errorMessage == nil { editingCard = nil }
  }

  /// The events that make an item's card what the draft says: title, priority, estimate, due date, repeat,
  /// notes and tags, the same for a task and a project.
  private func cardEvents(of taskID: TaskID, _ draft: TaskCardDraft, log: [EventEnvelope]) throws(CommandError)
    -> [EventEnvelope]
  {
    let day = planDate
    var events = try commands.rename(taskID: taskID, to: draft.title, log: log)
    events += try commands.prioritize(taskID: taskID, as: draft.priority, log: log + events)
    events += try commands.estimate(taskID: taskID, as: draft.estimate, log: log + events)
    events += try commands.setDue(
      taskID: taskID, to: draft.due?.date, isHard: draft.due?.isHard ?? false, log: log + events)
    events += try commands.setRepeat(taskID: taskID, to: draft.repeatRule, dueIfNone: day, log: log + events)
    events += try commands.setNotes(taskID: taskID, to: draft.notes, log: log + events)
    events += try commands.setTags(taskID: taskID, to: draft.tags, log: log + events)
    return events
  }

  /// Keeps what was typed on a project's card, which has the fields of a task's, a kind and how and when it is
  /// reviewed, and leaves edit mode. A blank title keeps the card in edit mode and writes nothing.
  public func saveCard(ofProject projectID: TaskID, _ draft: TaskCardDraft, kind: ProjectKind) {
    guard !draft.title.allSatisfy(\.isWhitespace) else { return }
    perform { (log) throws(CommandError) in
      var events = try cardEvents(of: projectID, draft, log: log)
      events += try commands.setKind(of: projectID, to: kind, log: log + events)
      if let review = draft.review {
        events += try commands.setReviewInterval(of: projectID, to: review.interval, log: log + events)
        if let next = review.nextReview {
          events += try commands.setNextReview(of: projectID, to: next, log: log + events)
        }
      }
      return events
    }
    if errorMessage == nil { editingCard = nil }
  }
}
