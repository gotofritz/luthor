/// Creates a tag in a view. Tags belong to a view, so `@calls` at work and at home are different tags.
public struct TagCreated: Equatable, Codable, Sendable {
  public let tagID: TagID
  public let name: String
  public let viewID: ViewID

  public init(tagID: TagID, name: String, viewID: ViewID) {
    self.tagID = tagID
    self.name = name
    self.viewID = viewID
  }
}

/// Puts a tag on an open task of the tag's view.
public struct TaskTagged: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let tagID: TagID

  public init(taskID: TaskID, tagID: TagID) {
    self.taskID = taskID
    self.tagID = tagID
  }
}

/// Takes a tag off a task.
public struct TaskUntagged: Equatable, Codable, Sendable {
  public let taskID: TaskID
  public let tagID: TagID

  public init(taskID: TaskID, tagID: TagID) {
    self.taskID = taskID
    self.tagID = tagID
  }
}

/// Deletes a tag, and takes it off every task that carries it. Ignored for a tag that does not exist.
public struct TagDeleted: Equatable, Codable, Sendable {
  public let tagID: TagID

  public init(tagID: TagID) {
    self.tagID = tagID
  }
}
