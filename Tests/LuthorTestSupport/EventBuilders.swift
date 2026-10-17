import LuthorDomain

/// Builds a `TaskCaptured` envelope with short, readable defaults.
public func captured(
  _ task: String,
  _ title: String,
  id: String? = nil,
  view: String = "default",
  device: String = "mac",
  lamport: UInt64 = 1
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "capture-\(task)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskCaptured(TaskCaptured(taskID: TaskID(task), title: title, viewID: ViewID(view)))
  )
}

/// Builds a `TaskCompleted` envelope with short, readable defaults.
public func completed(
  _ task: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "complete-\(task)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskCompleted(TaskCompleted(taskID: TaskID(task)))
  )
}

/// Builds a `ProjectCreated` envelope with short, readable defaults.
public func projectCreated(
  _ project: String,
  _ title: String,
  kind: ProjectKind = .parallel,
  id: String? = nil,
  view: String = "default",
  device: String = "mac",
  lamport: UInt64 = 1
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "create-\(project)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .projectCreated(
      ProjectCreated(projectID: ProjectID(project), title: title, kind: kind, viewID: ViewID(view)))
  )
}

/// Builds a `TaskMovedToProject` envelope with short, readable defaults.
public func moved(
  _ task: String,
  to project: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "move-\(task)-\(project)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskMovedToProject(TaskMovedToProject(taskID: TaskID(task), projectID: ProjectID(project)))
  )
}

/// Builds a `ProjectCompleted` envelope with short, readable defaults.
public func projectCompleted(
  _ project: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "complete-\(project)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .projectCompleted(ProjectCompleted(projectID: ProjectID(project)))
  )
}

/// Builds a `ViewCreated` envelope with short, readable defaults.
public func viewCreated(
  _ view: String,
  _ name: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 1
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "create-view-\(view)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .viewCreated(ViewCreated(viewID: ViewID(view), name: name))
  )
}

/// Builds a `ViewRenamed` envelope with short, readable defaults.
public func viewRenamed(
  _ view: String,
  to name: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "rename-view-\(view)-\(name)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .viewRenamed(ViewRenamed(viewID: ViewID(view), name: name))
  )
}

/// Builds a `TaskMovedToView` envelope with short, readable defaults.
public func movedToView(
  _ task: String,
  toView view: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "move-\(task)-view-\(view)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskMovedToView(TaskMovedToView(taskID: TaskID(task), viewID: ViewID(view)))
  )
}

/// Builds a `ProjectMovedToView` envelope with short, readable defaults.
public func projectMovedToView(
  _ project: String,
  toView view: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "move-\(project)-view-\(view)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .projectMovedToView(ProjectMovedToView(projectID: ProjectID(project), viewID: ViewID(view)))
  )
}

public func item(_ task: String, _ title: String, in project: String? = nil, view: String = "default") -> TaskItem {
  TaskItem(id: TaskID(task), title: title, viewID: ViewID(view), projectID: project.map(ProjectID.init))
}

public func project(
  _ project: String,
  _ title: String,
  kind: ProjectKind = .parallel,
  view: String = "default",
  tasks: [TaskItem] = []
) -> Project {
  Project(id: ProjectID(project), title: title, kind: kind, viewID: ViewID(view), tasks: tasks)
}
