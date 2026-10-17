import LuthorDomain

/// Builds a `TaskCaptured` envelope with short, readable defaults.
public func captured(
  _ task: String,
  _ title: String,
  id: String? = nil,
  view: String = "default",
  on day: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 1
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "capture-\(task)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskCaptured(
      TaskCaptured(taskID: TaskID(task), title: title, viewID: ViewID(view), createdOn: day.map(date)))
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
  under parent: String? = nil,
  id: String? = nil,
  view: String = "default",
  on day: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 1
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "create-\(project)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .projectCreated(
      ProjectCreated(
        projectID: ProjectID(project), title: title, kind: kind, viewID: ViewID(view),
        parentID: parent.map(ProjectID.init), createdOn: day.map(date)))
  )
}

/// Builds a `ProjectMovedToProject` envelope with short, readable defaults; a `nil` parent un-nests.
public func nested(
  _ project: String,
  under parent: String?,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "nest-\(project)-\(parent ?? "top")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .projectMovedToProject(
      ProjectMovedToProject(projectID: ProjectID(project), parentID: parent.map(ProjectID.init)))
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

/// Builds a `TaskPrioritized` envelope with short, readable defaults; a `nil` priority clears it.
public func prioritized(
  _ task: String,
  as priority: Priority?,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "prioritize-\(task)-\(priority?.rawValue ?? "none")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskPrioritized(TaskPrioritized(taskID: TaskID(task), priority: priority))
  )
}

/// Builds a `TaskEstimated` envelope with short, readable defaults; a `nil` estimate clears it.
public func estimated(
  _ task: String,
  as minutes: Int?,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "estimate-\(task)-\(minutes.map(String.init) ?? "none")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskEstimated(TaskEstimated(taskID: TaskID(task), minutes: minutes))
  )
}

public func item(
  _ task: String,
  _ title: String,
  in project: String? = nil,
  view: String = "default",
  priority: Priority? = nil,
  estimate: Int? = nil,
  notes: String? = nil,
  createdOn day: String? = nil
) -> TaskItem {
  TaskItem(
    id: TaskID(task), title: title, viewID: ViewID(view), projectID: project.map(ProjectID.init),
    priority: priority, estimate: estimate, notes: notes, createdOn: day.map(date))
}

/// A project as replay lists it. `tasks` are its children; `children` replaces them where sub-projects
/// are mixed in.
public func project(
  _ project: String,
  _ title: String,
  kind: ProjectKind = .parallel,
  view: String = "default",
  under parent: String? = nil,
  tasks: [TaskItem] = [],
  children: [ProjectChild]? = nil,
  notes: String? = nil,
  createdOn day: String? = nil
) -> Project {
  Project(
    id: ProjectID(project), title: title, kind: kind, viewID: ViewID(view), parentID: parent.map(ProjectID.init),
    children: children ?? tasks.map(ProjectChild.task), notes: notes, createdOn: day.map(date))
}

/// A sub-project as a child of its parent.
public func sub(_ project: String) -> ProjectChild {
  .project(ProjectID(project))
}

/// Builds a `SettingChanged` envelope with short, readable defaults; a `nil` value clears it, and a
/// `nil` view makes it global.
public func settingChanged(
  _ key: SettingKey,
  to value: String?,
  view: String? = nil,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 1
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "setting-\(key.rawValue)-\(view ?? "global")-\(value ?? "clear")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .settingChanged(SettingChanged(key: key, value: value, viewID: view.map(ViewID.init)))
  )
}

/// A `CalendarDate` from `"2026-10-19"`; stops the test run on a string that is not a date.
public func date(_ iso: String) -> CalendarDate {
  guard let parsed = CalendarDate(isoString: iso) else { fatalError("not a calendar date: \(iso)") }
  return parsed
}

/// Builds a `TaskScheduled` envelope with short, readable defaults.
public func scheduled(
  _ task: String,
  on day: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "schedule-\(task)-\(day)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskScheduled(TaskScheduled(taskID: TaskID(task), date: date(day)))
  )
}

/// Builds a `TaskUnscheduled` envelope with short, readable defaults.
public func unscheduled(
  _ task: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "unschedule-\(task)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskUnscheduled(TaskUnscheduled(taskID: TaskID(task)))
  )
}

/// Builds a `DayPlanOrdered` envelope with short, readable defaults.
public func planOrdered(
  _ tasks: [String],
  on day: String,
  view: String = "default",
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "order-\(view)-\(day)-\(tasks.joined(separator: ","))"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .dayPlanOrdered(DayPlanOrdered(viewID: ViewID(view), date: date(day), taskIDs: tasks.map(TaskID.init)))
  )
}

/// Builds a `DayCapacitySet` envelope with short, readable defaults; `nil` minutes clears it.
public func dayCapacitySet(
  _ minutes: Int?,
  on day: String,
  view: String = "default",
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 2
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "capacity-\(view)-\(day)-\(minutes.map(String.init) ?? "clear")"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .dayCapacitySet(DayCapacitySet(viewID: ViewID(view), date: date(day), minutes: minutes))
  )
}

/// Builds a `TaskDelegated` envelope with short, readable defaults.
public func delegated(
  _ task: String,
  to name: String,
  since: String = "2026-10-19",
  followUp: String? = nil,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "delegate-\(task)-\(name)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskDelegated(
      TaskDelegated(taskID: TaskID(task), to: name, since: date(since), followUpDate: followUp.map(date)))
  )
}

/// Builds a `TaskReclaimed` envelope with short, readable defaults.
public func reclaimed(
  _ task: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 4
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "reclaim-\(task)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskReclaimed(TaskReclaimed(taskID: TaskID(task)))
  )
}

/// Builds a `TaskDropped` envelope with short, readable defaults.
public func dropped(
  _ task: String,
  id: String? = nil,
  device: String = "mac",
  lamport: UInt64 = 3
) -> EventEnvelope {
  EventEnvelope(
    id: EventID(id ?? "drop-\(task)"),
    deviceID: DeviceID(device),
    lamport: lamport,
    payload: .taskDropped(TaskDropped(taskID: TaskID(task)))
  )
}
