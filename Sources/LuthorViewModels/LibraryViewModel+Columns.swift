import LuthorDomain

/// What the Miller columns offer: adding items from a column's plus button, the notes on a card, and which
/// card the last column shows.
extension LibraryViewModel {
  /// Adds a task to a project, or with no project to the inbox of the current view. A blank title adds
  /// nothing.
  public func addTask(titled title: String, to parentID: TaskID?) {
    let viewID = currentView
    let day = clock()
    perform { (log) throws(CommandError) in
      if let parentID {
        try commands.capture(title: title, into: parentID, today: day, log: log)
      } else {
        try commands.capture(title: title, in: viewID, today: day, log: log)
      }
    }
  }

  /// Adds a project inside a project, or with no parent a top-level one in the current view. A blank title
  /// adds nothing.
  public func addProject(titled title: String, kind: ProjectKind, under parentID: TaskID?) {
    let viewID = currentView
    let day = clock()
    perform { (log) throws(CommandError) in
      if let parentID {
        try commands.createProject(title: title, kind: kind, under: parentID, today: day, log: log)
      } else {
        try commands.createProject(title: title, kind: kind, in: viewID, today: day, log: log)
      }
    }
  }

  /// Adds a note to a task or project, a bullet after the ones it has. Blank text adds nothing.
  public func appendNote(_ text: String, to itemID: TaskID) {
    perform { (log) throws(CommandError) in try commands.appendNote(taskID: itemID, text, log: log) }
  }

  /// Deletes the note at `position` among the bullets of a task or project.
  public func deleteNote(at position: Int, of itemID: TaskID) {
    perform { (log) throws(CommandError) in try commands.deleteNote(taskID: itemID, at: position, log: log) }
  }

  /// Replaces the note at `position` among the bullets of a task or project; blank text deletes it.
  public func editNote(at position: Int, of itemID: TaskID, to text: String) {
    perform { (log) throws(CommandError) in
      try commands.editNote(taskID: itemID, at: position, to: text, log: log)
    }
  }

  /// What a click on the empty part of a column does: the column lists the children of the project
  /// `parentID`, or the top-level projects for `nil`. Everything beyond it closes, and the first column leaves
  /// no project shown; otherwise the project is shown with no task picked.
  public func deselectColumn(of parentID: TaskID?) {
    guard let parentID else {
      sidebarSelection = .inbox
      selection = nil
      editingCard = nil
      newItem = nil
      present()
      return
    }
    open(.project(parentID))
  }

  /// The card the last column shows: the task picked, else the project the columns lead to; `nil` when there
  /// is neither.
  public var cardTarget: CardTarget? {
    if let task = selectedTask { return .task(task.id) }
    if section == .projects, let project = shownProject { return .project(project.id) }
    return nil
  }
}
