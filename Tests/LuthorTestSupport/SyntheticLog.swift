import LuthorDomain

/// A deterministic log of heavy use, for measuring: on each working day, eight tasks captured (some into one of
/// twelve projects), five of them planned, timed and completed, and the day reviewed; about 35 events a day,
/// so some 9,000 a year. The same `years` always give the same log.
public func syntheticLog(years: Int, from start: String = "2023-01-02") -> [EventEnvelope] {
  var events: [EventEnvelope] = []
  var lamport: UInt64 = 0
  func add(_ make: (UInt64) -> EventEnvelope) {
    lamport += 1
    events.append(make(lamport))
  }
  for project in 0..<12 {
    add { projectCreated("p\(project)", "Project \(project)", lamport: $0) }
  }
  let first = date(start)
  let days = years * 365
  for offset in 0..<days {
    let day = first.adding(days: offset)
    guard day.weekday != .saturday, day.weekday != .sunday else { continue }
    let iso = day.isoString
    let tasks = (0..<8).map { "t\(offset)-\($0)" }
    for (index, task) in tasks.enumerated() {
      let project = index % 3 == 0 ? "p\((offset + index) % 12)" : nil
      add { captured(task, "Task \(task)", on: iso, under: project, lamport: $0) }
    }
    for task in tasks.prefix(3) {
      add { prioritized(task, as: .important, lamport: $0) }
      add { estimated(task, as: 30, lamport: $0) }
    }
    let planned = Array(tasks.prefix(5))
    for task in planned { add { scheduled(task, on: iso, lamport: $0) } }
    add { planOrdered(planned, on: iso, lamport: $0) }
    for task in planned {
      add { timeLogged(task, on: iso, minutes: 25, lamport: $0) }
      add { completed(task, lamport: $0) }
    }
    add { dayReviewed(on: iso, note: "Day \(offset)", lamport: $0) }
  }
  return events
}
