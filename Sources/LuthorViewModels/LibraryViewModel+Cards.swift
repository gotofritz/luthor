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
  public func saveCard(
    ofTask taskID: TaskID, title: String, priority: Priority?, estimate: Int?, due: DueDate?, notes: String
  ) {
    guard !title.allSatisfy(\.isWhitespace) else { return }
    perform { (log) throws(CommandError) in
      var events = try commands.rename(taskID: taskID, to: title, log: log)
      events += try commands.prioritize(taskID: taskID, as: priority, log: log + events)
      events += try commands.estimate(taskID: taskID, as: estimate, log: log + events)
      events += try commands.setDue(
        taskID: taskID, to: due?.date, isHard: due?.isHard ?? false, log: log + events)
      events += try commands.setNotes(taskID: taskID, to: notes, log: log + events)
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
