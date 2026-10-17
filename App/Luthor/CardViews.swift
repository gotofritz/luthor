import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The card of the task selected, in a column of its own after the list the task is in. It shows the day the
/// task was created and its notes, and not the title, which the list before it already shows; the pencil
/// turns it into the editor of the title, priority, estimate and notes, closed by OK or Cancel. A completed
/// task shows its card too, with no pencil until it is reopened.
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
      NotesView(notes: task.notes)
    }
  }

  private var completedLine: some View {
    HStack {
      Label("Completed", systemImage: "checkmark.circle.fill")
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

  /// Estimates offered next to the one the task has, in minutes.
  private static let estimateChoices = [5, 15, 30, 60]

  @State private var title: String
  @State private var priority: Priority?
  @State private var estimate: Int?
  @State private var notes: String

  init(library: LibraryViewModel, task: TaskItem) {
    self.library = library
    self.task = task
    _title = State(initialValue: task.title)
    _priority = State(initialValue: task.priority)
    _estimate = State(initialValue: task.estimate)
    _notes = State(initialValue: task.notes ?? "")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      TextField("Title", text: $title)
        .textFieldStyle(.roundedBorder)
        .font(.title3)
        .onSubmit(save)
      Picker("Priority", selection: $priority) {
        Text("None").tag(Priority?.none)
        ForEach(Priority.allCases, id: \.self) { priority in
          Label(priority.title, systemImage: priority.symbol).tag(Priority?.some(priority))
        }
      }
      Picker("Estimate", selection: $estimate) {
        Text("None").tag(Int?.none)
        ForEach(estimateChoices, id: \.self) { minutes in
          Text("\(minutes)m").tag(Int?.some(minutes))
        }
      }
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
    library.saveCard(ofTask: task.id, title: title, priority: priority, estimate: estimate, notes: notes)
  }

  /// The choices, plus the estimate the task has when it is none of them.
  private var estimateChoices: [Int] {
    Array(Set(Self.estimateChoices + (task.estimate.map { [$0] } ?? []))).sorted()
  }

  private var projectTitle: String {
    task.projectID.flatMap { id in library.knownProjects.first { $0.id == id }?.title } ?? "Inbox"
  }
}

/// The card of the project whose column it heads, above its tasks and sub-projects. Like a task card it
/// shows the day the project was created and its notes, not the title the column before it shows, until the
/// pencil opens the editor of the title, kind and notes. A completed project shows its card too, with no
/// pencil until it is reopened.
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
          Label("Completed", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.secondary)
          Spacer()
          if library.reopenableProjectIDs.contains(project.id) {
            Button("Reopen") { library.reopenProject(project.id) }
          }
        }
      }
      NotesView(notes: project.notes)
    }
  }
}

/// A project card in edit mode. What is typed stays here until OK hands it to the view model; Cancel drops it.
private struct ProjectCardEditor: View {
  let library: LibraryViewModel
  let project: Project

  @State private var title: String
  @State private var kind: ProjectKind
  @State private var notes: String

  init(library: LibraryViewModel, project: Project) {
    self.library = library
    self.project = project
    _title = State(initialValue: project.title)
    _kind = State(initialValue: project.kind)
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
      if let history = library.estimateHistory(ofProject: project.id) {
        LabeledContent("History", value: history.summary)
      }
      CreatedLine(day: project.createdOn)
      NotesEditor(notes: $notes)
      EditButtons(save: save) { library.cancelCardEdit() }
    }
  }

  private func save() {
    library.saveCard(ofProject: project.id, title: title, kind: kind, notes: notes)
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

/// Plain-text notes with their web addresses made clickable, or "No notes".
private struct NotesView: View {
  let notes: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Notes")
        .font(.headline)
      if let notes {
        Text(Self.linkified(notes))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Text("No notes")
          .foregroundStyle(.secondary)
      }
    }
  }

  /// The notes with each web address a link.
  static func linkified(_ notes: String) -> AttributedString {
    var text = AttributedString(notes)
    for link in NoteLinks.links(in: notes) {
      guard let range = Range(link.range, in: text) else { continue }
      text[range].link = link.url
    }
    return text
  }
}

/// The notes of a card in edit mode: a text editor that is open from the start, with no Edit of its own.
private struct NotesEditor: View {
  @Binding var notes: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Notes")
        .font(.headline)
      TextEditor(text: $notes)
        .font(.body)
        .frame(minHeight: 120)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.4)))
    }
  }
}
