import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The card of the task selected, in a column of its own after the list the task is in. It shows the day the
/// task was created, its due date, its tags and its notes, and not the title, which the list before it already shows;
/// the pencil turns it into the editor of the title, priority, estimate, due date, tags and notes, closed by OK
/// or Cancel. The notes are bullets, each with a button that deletes it, and a field below them adds one without
/// the editor. A completed task shows its card too, with no pencil and no field until it is reopened.
struct TaskCardColumn: View {
  @Bindable var library: LibraryViewModel
  let task: TaskItem

  private var isCompleted: Bool {
    library.completedTaskIDs.contains(task.id)
  }

  var body: some View {
    ScrollView {
      Group {
        if library.editingCard == .task(task.id) {
          TaskCardEditor(library: library, task: task)
        } else {
          readOnlyCard
        }
      }
      .padding(12)
    }
    .frame(width: 300)
    .id(task.id)
  }

  private var readOnlyCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      CardToolbar(day: task.createdOn, canEdit: !isCompleted) { library.editCard(.task(task.id)) }
      if isCompleted {
        completedLine
      }
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

/// A task card in edit mode. What is typed stays here until OK hands it to the view model; Cancel drops it.
private struct TaskCardEditor: View {
  let library: LibraryViewModel
  let task: TaskItem

  @State private var title: String
  @State private var fields: CardFields
  @State private var notes: String

  init(library: LibraryViewModel, task: TaskItem) {
    self.library = library
    self.task = task
    _title = State(initialValue: task.title)
    _fields = State(
      initialValue: CardFields(library: library, id: task.id, priority: task.priority, estimate: task.estimate))
    _notes = State(initialValue: task.notes ?? "")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("Title", text: $title)
        .textFieldStyle(.roundedBorder)
        .font(.title3)
        .onSubmit(save)
      CardFieldsForm(library: library, fields: $fields, currentEstimate: task.estimate, submit: save)
      if let history = library.estimateHistory(ofTask: task.id) {
        LabeledContent("History", value: history.summary)
      }
      LabeledContent("Project", value: projectTitle)
      CreatedLine(day: task.createdOn)
      NotesEditor(notes: $notes)
      EditButtons(save: save) { library.cancelCardEdit() }
    }
  }

  private func save() {
    library.saveCard(ofTask: task.id, fields.draft(title: title, notes: notes))
  }

  private var projectTitle: String {
    task.parentID.flatMap { id in library.knownProjects.first { $0.id == id }?.title } ?? "Inbox"
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

/// The card of a project. Like a task card it shows the day the project was created, whether it is completed or
/// dropped, the day it is to be reviewed next and its notes, not the title the column before it shows, until the
/// pencil opens the editor of the title, kind and notes. A completed project shows its card too, with no pencil
/// until it is reopened.
struct ProjectCard: View {
  @Bindable var library: LibraryViewModel
  let project: Project

  private var isCompleted: Bool {
    library.completedProjectIDs.contains(project.id)
  }

  var body: some View {
    Group {
      if library.editingCard == .project(project.id) {
        ProjectCardEditor(library: library, project: project)
      } else {
        readOnlyCard
      }
    }
    .padding(12)
    .id(project.id)
  }

  private var readOnlyCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      CardToolbar(day: project.createdOn, canEdit: !isCompleted) { library.editCard(.project(project.id)) }
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
        Label("Next review \(next.isoString)", systemImage: "eyeglasses")
          .font(.callout)
          .foregroundStyle(next < library.today ? Color.red : Color.primary)
      }
      CardNotesView(library: library, itemID: project.id, notes: project.notes, canAdd: !isCompleted)
    }
  }
}

/// A project card in edit mode. What is typed stays here until OK hands it to the view model; Cancel drops it.
private struct ProjectCardEditor: View {
  let library: LibraryViewModel
  let project: Project

  @State private var title: String
  @State private var kind: ProjectKind
  @State private var fields: CardFields
  @State private var notes: String

  init(library: LibraryViewModel, project: Project) {
    self.library = library
    self.project = project
    _title = State(initialValue: project.title)
    _kind = State(initialValue: project.kind)
    _fields = State(
      initialValue: CardFields(
        library: library, id: project.id, priority: project.priority, estimate: project.estimate))
    _notes = State(initialValue: project.notes ?? "")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      TextField("Title", text: $title)
        .textFieldStyle(.roundedBorder)
        .font(.title3)
        .onSubmit(save)
      Picker("Kind", selection: $kind) {
        Label("Parallel", systemImage: ProjectKind.parallel.symbol).tag(ProjectKind.parallel)
        Label("Sequential", systemImage: ProjectKind.sequential.symbol).tag(ProjectKind.sequential)
      }
      .pickerStyle(.segmented)
      CardFieldsForm(library: library, fields: $fields, currentEstimate: project.estimate, submit: save)
      if let history = library.estimateHistory(ofProject: project.id) {
        LabeledContent("History", value: history.summary)
      }
      CreatedLine(day: project.createdOn)
      NotesEditor(notes: $notes)
      EditButtons(save: save) { library.cancelCardEdit() }
    }
  }

  private func save() {
    library.saveCard(ofProject: project.id, fields.draft(title: title, notes: notes), kind: kind)
  }
}

/// The top line of a read-only card: the day it was created, with the pencil that opens the editor beside
/// it. No text on the button, as the pencil says it; a completed card has none.
private struct CardToolbar: View {
  let day: CalendarDate?
  let canEdit: Bool
  let edit: () -> Void

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      CreatedLine(day: day)
      Spacer()
      if canEdit {
        Button(action: edit) {
          Image(systemName: "pencil")
        }
        .buttonStyle(.borderless)
        .help("Edit")
        .accessibilityLabel("Edit")
      }
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
private struct EditButtons: View {
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
