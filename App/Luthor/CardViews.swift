import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The card of the task selected, in a column of its own after the list the task is in. It shows the day the
/// task was created and every field of the task, each one changed by clicking it (see CardLiveFields); the notes
/// are bullets, each with a button that deletes it, and a field below them adds one. A completed task shows its
/// card too, as lines of text and with no field until it is reopened.
struct TaskCardColumn: View {
  @Bindable var library: LibraryViewModel
  let task: TaskItem

  private var isCompleted: Bool {
    library.completedTaskIDs.contains(task.id)
  }

  var body: some View {
    ScrollView {
      card
        .padding(12)
    }
    .frame(width: 300)
    .id(task.id)
  }

  private var card: some View {
    VStack(alignment: .leading, spacing: 12) {
      CreatedLine(day: task.createdOn)
      if isCompleted {
        completedLine
      }
      if isCompleted {
        if let due = library.dueDate(of: task.id) {
          DueLine(due: due, today: library.today)
        }
        if let rule = library.repeatRule(of: task.id) {
          RepeatLine(rule: rule)
        }
        if let tags = tagLine(of: library.tagItems(of: task.id)) {
          Label(tags, systemImage: "tag")
            .font(.callout)
        }
      } else {
        CardLiveFields(
          library: library, id: task.id, isProject: false, priority: task.priority, estimate: task.estimate,
          title: task.title)
      }
      CardNotesView(library: library, itemID: task.id, notes: task.notes, canAdd: !isCompleted)
      if !isCompleted {
        Button("Add Tasks") { library.addTasks(to: task.id) }
          .help("Turn this task into a project and add tasks to it")
      }
    }
  }

  private var completedLine: some View {
    HStack {
      let isDropped = library.droppedTaskIDs.contains(task.id)
      Label(isDropped ? "Dropped" : "Completed", systemImage: isDropped ? "xmark.circle.fill" : "checkmark.circle.fill")
        .foregroundStyle(.secondary)
      Spacer()
      if library.reopenableTaskIDs.contains(task.id) {
        Button("Reopen") { library.reopen(task.id) }
      }
    }
  }
}

/// The card of the project shown, in a column of its own after the project's column, where a task's card goes
/// when one is picked.
struct ProjectCardColumn: View {
  @Bindable var library: LibraryViewModel
  let project: Project

  var body: some View {
    ScrollView {
      ProjectCard(library: library, project: project)
    }
    .frame(width: 300)
  }
}

/// The card of a project. Like a task card it shows the day the project was created and every field of the
/// project, each one changed by clicking it (see CardLiveFields), with its notes below. A completed project shows
/// its card too, as lines of text, until it is reopened.
struct ProjectCard: View {
  @Bindable var library: LibraryViewModel
  let project: Project

  private var isCompleted: Bool {
    library.completedProjectIDs.contains(project.id)
  }

  var body: some View {
    card
      .padding(12)
      .id(project.id)
  }

  private var card: some View {
    VStack(alignment: .leading, spacing: 10) {
      CreatedLine(day: project.createdOn)
      if isCompleted {
        HStack {
          let isDropped = library.droppedProjectIDs.contains(project.id)
          Label(
            isDropped ? "Dropped" : "Completed", systemImage: isDropped ? "xmark.circle.fill" : "checkmark.circle.fill"
          )
          .foregroundStyle(.secondary)
          Spacer()
          if library.reopenableProjectIDs.contains(project.id) {
            Button("Reopen") { library.reopenProject(project.id) }
          }
        }
      }
      if let minutes = library.rolledUpEstimate(of: project.id) {
        Label(
          project.estimate == nil ? "\(minutes)m from its tasks" : "\(minutes)m",
          systemImage: "hourglass"
        )
        .font(.callout)
      }
      if isCompleted {
        if let due = library.dueDate(of: project.id) {
          DueLine(due: due, today: library.today)
        }
        if let rule = library.repeatRule(of: project.id) {
          RepeatLine(rule: rule)
        }
        if let tags = tagLine(of: library.tagItems(of: project.id)) {
          Label(tags, systemImage: "tag")
            .font(.callout)
        }
        if let next = library.nextReviewDate(of: project.id) {
          Label(
            "Next review \(next.isoString), \(library.reviewInterval(of: project.id).title.lowercased())",
            systemImage: "eyeglasses"
          )
          .font(.callout)
          .foregroundStyle(next < library.today ? Color.red : Color.primary)
        }
      } else {
        CardLiveFields(
          library: library, id: project.id, isProject: true, priority: project.priority,
          estimate: project.estimate, title: project.title, kind: project.kind)
      }
      CardNotesView(library: library, itemID: project.id, notes: project.notes, canAdd: !isCompleted)
    }
  }
}

/// When the task is due: a hard deadline or a target date, in red once the day has passed.
private struct DueLine: View {
  let due: DueDate
  let today: CalendarDate

  var body: some View {
    Label(
      "\(due.isHard ? "Deadline" : "Target date") \(due.date.isoString)",
      systemImage: due.isHard ? "exclamationmark.circle" : "calendar"
    )
    .font(.callout)
    .foregroundStyle(due.date < today ? Color.red : Color.primary)
  }
}

extension CalendarDate {
  /// The day of `date` by the system's calendar.
  init?(dayOf date: Date) {
    let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
    guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
    self.init(year: year, month: month, day: day)
  }

  /// The start of the day by the system's calendar.
  var startOfDay: Date? {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
  }
}

/// The day a card's task or project was created; nothing for one created before the day was kept.
private struct CreatedLine: View {
  let day: CalendarDate?

  var body: some View {
    if let day {
      Text("Created \(day.isoString)")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }
}

/// OK keeps what was typed on a card, Cancel drops it.
struct EditButtons: View {
  let save: () -> Void
  let cancel: () -> Void

  var body: some View {
    HStack {
      Spacer()
      Button("Cancel", action: cancel)
      Button("OK", action: save)
    }
  }
}
