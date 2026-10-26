/// Who a task was handed to, since when, and when it comes back to the candidates.
public struct Delegation: Equatable, Sendable {
  public let person: String
  /// The day it was handed over.
  public let since: CalendarDate
  /// The day it comes back; `nil` until it is reclaimed.
  public let followUpDate: CalendarDate?

  public init(to person: String, since: CalendarDate, followUpDate: CalendarDate?) {
    self.person = person
    self.since = since
    self.followUpDate = followUpDate
  }

  /// Whether the follow-up date has come on `today`. With no follow-up date it never does.
  public func isFollowUpDue(on today: CalendarDate) -> Bool {
    followUpDate.map { $0 <= today } ?? false
  }
}

/// One view's plan for one day: the key of its manual order and its capacity.
struct DayKey: Hashable, Sendable {
  let viewID: ViewID
  let date: CalendarDate
}

/// When a planned task starts, and the day that was set for.
struct TaskStart: Equatable, Sendable {
  let date: CalendarDate
  let minute: Int
}

/// A block of untracked time on a day, such as lunch: minutes after midnight.
public struct DayBlock: Equatable, Identifiable, Sendable {
  public let id: BlockID
  public let title: String
  public let start: Int
  public let end: Int

  public init(id: BlockID, title: String, start: Int, end: Int) {
    self.id = id
    self.title = title
    self.start = start
    self.end = end
  }
}

/// A block with the view and day it is on.
struct PlacedBlock: Equatable, Sendable {
  let viewID: ViewID
  let date: CalendarDate
  let block: DayBlock
}

/// A task in a day's plan, or a candidate for it, with the minutes it counts for and why it sits there.
public struct PlanEntry: Equatable, Sendable {
  public let task: TaskItem
  /// Minutes it counts for: its estimate, or the default estimate while it has none.
  public let minutes: Int
  /// Whether `minutes` is the default estimate, not one the task was given.
  public let isUnestimated: Bool
  /// What put it here: the order the user chose, or the rule that suggested it.
  public let reason: String
  /// The minute after midnight it was told to start at; `nil` while it follows the tasks before it.
  public let start: Int?

  public init(task: TaskItem, minutes: Int, isUnestimated: Bool, reason: String, start: Int? = nil) {
    self.task = task
    self.minutes = minutes
    self.isUnestimated = isUnestimated
    self.reason = reason
    self.start = start
  }
}

/// How much of a day is spoken for. The buffer is protected capacity, never a task.
public struct DayCapacity: Equatable, Sendable {
  /// The day's capacity before the buffer.
  public let availableMinutes: Int
  /// Held back for interruptions and the unexpected.
  public let bufferMinutes: Int
  /// The minutes of the tasks in the plan, unestimated ones at the default estimate.
  public let plannedMinutes: Int
  /// How many of the planned tasks have no estimate of their own.
  public let unestimatedCount: Int

  public init(availableMinutes: Int, bufferMinutes: Int, plannedMinutes: Int, unestimatedCount: Int) {
    self.availableMinutes = availableMinutes
    self.bufferMinutes = bufferMinutes
    self.plannedMinutes = plannedMinutes
    self.unestimatedCount = unestimatedCount
  }

  /// What can be planned: the capacity less the buffer.
  public var usableMinutes: Int {
    availableMinutes - bufferMinutes
  }

  /// What is left to plan; negative when the plan is overloaded.
  public var remainingMinutes: Int {
    usableMinutes - plannedMinutes
  }

  /// Whether more is planned than can be done. A warning, never a refusal.
  public var isOverloaded: Bool {
    plannedMinutes > usableMinutes
  }
}

/// One view's day: the tasks planned for it in order, the tasks that could be pulled in, and the capacity.
public struct DayPlan: Equatable, Sendable {
  public let viewID: ViewID
  public let date: CalendarDate
  public let entries: [PlanEntry]
  public let candidates: [PlanEntry]
  public let capacity: DayCapacity
  /// When the day starts and ends.
  public let hours: DayHours
  /// The blocks of untracked time on the day, earliest first; tasks go round them.
  public let blocks: [DayBlock]
  /// The sessions of the planned tasks: stretches of their day set apart from the rest of it.
  public let sessions: [PlanSession]
  /// The tasks planned for the day that are done, where they were: they keep their place and cannot be moved.
  public let done: [PlanEntry]

  public init(
    viewID: ViewID,
    date: CalendarDate,
    entries: [PlanEntry],
    candidates: [PlanEntry],
    capacity: DayCapacity,
    hours: DayHours = .builtIn,
    blocks: [DayBlock] = [],
    sessions: [PlanSession] = [],
    done: [PlanEntry] = []
  ) {
    self.viewID = viewID
    self.date = date
    self.entries = entries
    self.candidates = candidates
    self.capacity = capacity
    self.hours = hours
    self.blocks = blocks
    self.sessions = sessions
    self.done = done
  }

  /// The entries on the day's hours, each as long as the minutes it counts for, and never on top of another or
  /// on a block. A task with a start of its own stands there, unless something before it is in the way: it then
  /// moves to the end of that, and so does everything after it. The others follow one another in the plan's
  /// order from the start of the day, or from `notBefore` (the time now, on today) if that is later, in the
  /// gaps. A plan longer than the day runs past its end. Slots come earliest first. With `moving`, that entry
  /// is laid first at the minute `to`, as if it had been dropped there, and the others make room for it.
  public func slots(notBefore: Int = 0, moving: TaskID? = nil, to minute: Int = 0) -> [PlanSlot] {
    layout(notBefore: notBefore, moving: moving, to: minute).slots
  }

  /// The day laid out: the slots of the entries and the blocks, none on top of another. The blocks stand where
  /// they are, and the tasks go round them, unless something is being moved: `moving` (a task, at `minute`) or
  /// `movingBlock` is laid first, and everything else makes room for it, blocks included.
  public func layout(
    notBefore: Int = 0, moving: TaskID? = nil, to minute: Int = 0, movingBlock: DayBlock? = nil,
    movingSession: SessionID? = nil
  ) -> DayLayout {
    var packer = Packer()
    let lockedSlots = trimmed(done).map { packer.slot($0, from: $0.start ?? hours.start) }
    let lockedSessions = sessions.filter(\.isDone).map { packer.session($0, from: $0.start) }
    let own = trimmed(entries)
    let moved = own.first { $0.task.id == moving }.map { packer.slot($0, from: minute) }
    let draggedBlock = movingBlock.map { packer.block($0, from: $0.start) }
    let draggedSession = sessions.first { $0.id == movingSession }.map { packer.session($0, from: minute) }
    let resident = blocks.filter { $0.id != movingBlock?.id }
      .sorted { $0.start < $1.start }
      .map { packer.block($0, from: $0.start) }
    let fixedItems: [FixedItem] =
      sessions.filter { $0.id != movingSession && !$0.isDone }.map { FixedItem.session($0) }
      + own.filter { $0.start != nil && $0.task.id != moving }.map { FixedItem.task($0) }
    var fixedSlots: [PlanSlot] = []
    var fixedSessions: [SessionSlot] = []
    for item in fixedItems.enumerated().sorted(by: { ($0.element.start, $0.offset) < ($1.element.start, $1.offset) }) {
      switch item.element {
      case .task(let entry): fixedSlots.append(packer.slot(entry, from: entry.start ?? 0))
      case .session(let one): fixedSessions.append(packer.session(one, from: one.start))
      }
    }
    var cursor = max(hours.start, notBefore)
    var flowing: [PlanSlot] = []
    for entry in own where entry.start == nil && entry.task.id != moving {
      let placed = packer.slot(entry, from: cursor)
      flowing.append(placed)
      cursor = placed.end
    }
    return DayLayout(
      slots: (fixedSlots + flowing + (moved.map { [$0] } ?? [])).sorted { $0.start < $1.start },
      blocks: (resident + (draggedBlock.map { [$0] } ?? [])).sorted { $0.start < $1.start },
      sessions: (lockedSessions + fixedSessions + (draggedSession.map { [$0] } ?? [])).sorted { $0.start < $1.start },
      done: lockedSlots.sorted { $0.start < $1.start })
  }

  /// A task's own block is what its sessions leave of it, and goes when they take all of it.
  private func trimmed(_ list: [PlanEntry]) -> [PlanEntry] {
    list.compactMap { entry in
      let taken = sessions.filter { $0.task.id == entry.task.id }.reduce(0) { $0 + $1.minutes }
      guard entry.minutes > taken else { return nil }
      return PlanEntry(
        task: entry.task, minutes: entry.minutes - taken, isUnestimated: entry.isUnestimated, reason: entry.reason,
        start: entry.start)
    }
  }
}

/// What has a time of its own on a day: a task with a start, or a session.
private enum FixedItem {
  case task(PlanEntry)
  case session(PlanSession)

  var start: Int {
    switch self {
    case .task(let entry): entry.start ?? 0
    case .session(let session): session.start
    }
  }
}

/// Lays stretches on a day one after another, each pushed past what is already there.
private struct Packer {
  private var taken: [(start: Int, end: Int)] = []

  private mutating func place(length: Int, from first: Int) -> Int {
    var start = first
    while let clash = taken.first(where: { $0.start < start + length && $0.end > start }) {
      start = clash.end
    }
    taken.append((start: start, end: start + length))
    return start
  }

  mutating func slot(_ entry: PlanEntry, from first: Int) -> PlanSlot {
    let start = place(length: entry.minutes, from: first)
    return PlanSlot(entry: entry, start: start, end: start + entry.minutes)
  }

  mutating func block(_ block: DayBlock, from first: Int) -> DayBlock {
    let length = block.end - block.start
    let start = place(length: length, from: first)
    return DayBlock(id: block.id, title: block.title, start: start, end: start + length)
  }

  mutating func session(_ session: PlanSession, from first: Int) -> SessionSlot {
    let start = place(length: session.minutes, from: first)
    return SessionSlot(session: session, start: start, end: start + session.minutes)
  }
}

/// A stretch of a planned task's day set apart from the rest of it, as the plan holds it.
public struct PlanSession: Equatable, Identifiable, Sendable {
  public let id: SessionID
  public let task: TaskItem
  public let start: Int
  public let minutes: Int
  /// Whether the task is done, which locks the session in its place.
  public let isDone: Bool

  public init(id: SessionID, task: TaskItem, start: Int, minutes: Int, isDone: Bool = false) {
    self.id = id
    self.task = task
    self.start = start
    self.minutes = minutes
    self.isDone = isDone
  }
}

/// A session at its place in the day: minutes after midnight.
public struct SessionSlot: Equatable, Sendable {
  public let session: PlanSession
  public let start: Int
  public let end: Int
}

/// A day laid out: where the planned tasks and the blocks of untracked time stand, earliest first.
public struct DayLayout: Equatable, Sendable {
  public let slots: [PlanSlot]
  public let blocks: [DayBlock]
  public let sessions: [SessionSlot]
  /// The done tasks, where they stand; they never move.
  public let done: [PlanSlot]
}

/// A planned task at its place in the day: minutes after midnight.
public struct PlanSlot: Equatable, Sendable {
  public let entry: PlanEntry
  public let start: Int
  public let end: Int

  public init(entry: PlanEntry, start: Int, end: Int) {
    self.entry = entry
    self.start = start
    self.end = end
  }
}

/// A delegated task as the Waiting for list shows it.
public struct WaitingItem: Equatable, Sendable {
  public let task: TaskItem
  public let delegation: Delegation
  /// Whether the follow-up date has come, so the task is back among the candidates.
  public let isFollowUpDue: Bool

  public init(task: TaskItem, delegation: Delegation, isFollowUpDue: Bool) {
    self.task = task
    self.delegation = delegation
    self.isFollowUpDue = isFollowUpDue
  }
}
