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

  /// Leaves edit mode and drops what was typed.
  public func cancelCardEdit() {
    editingCard = nil
  }

  /// Keeps what was typed on a task's card and leaves edit mode. A blank title keeps the card in edit mode
  /// and writes nothing.
  public func saveCard(ofTask taskID: TaskID, _ draft: TaskCardDraft) {
    guard !draft.title.allSatisfy(\.isWhitespace) else { return }
    let day = planDate
    perform { (log) throws(CommandError) in
      var events = try commands.rename(taskID: taskID, to: draft.title, log: log)
      events += try commands.prioritize(taskID: taskID, as: draft.priority, log: log + events)
      events += try commands.estimate(taskID: taskID, as: draft.estimate, log: log + events)
      events += try commands.setDue(
        taskID: taskID, to: draft.due?.date, isHard: draft.due?.isHard ?? false, log: log + events)
      events += try commands.setRepeat(
        taskID: taskID, to: draft.repeatRule, dueIfNone: day, log: log + events)
      events += try commands.setNotes(taskID: taskID, to: draft.notes, log: log + events)
      events += try commands.setTags(taskID: taskID, to: draft.tags, log: log + events)
      return events
    }
    if errorMessage == nil { editingCard = nil }
  }

  /// Keeps what was typed on a project's card and leaves edit mode. A blank title keeps the card in edit
  /// mode and writes nothing.
  public func saveCard(ofProject projectID: ProjectID, title: String, kind: ProjectKind, notes: String) {
    guard !title.allSatisfy(\.isWhitespace) else { return }
    perform { (log) throws(CommandError) in
      var events = try commands.renameProject(projectID, to: title, log: log)
      events += try commands.setKind(of: projectID, to: kind, log: log + events)
      events += try commands.setNotes(ofProject: projectID, to: notes, log: log + events)
      return events
    }
    if errorMessage == nil { editingCard = nil }
  }
}
