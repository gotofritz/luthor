import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The card of the task selected: its title, priority, estimate, project and notes, in a column of its own
/// after the list the task is in. A completed task shows its card too, read-only until it is reopened.
struct TaskCardColumn: View {
  @Bindable var library: LibraryViewModel
  let task: TaskItem

  /// Estimates offered next to the one the task has, in minutes.
  private static let estimateChoices = [5, 15, 30, 60]

  @State private var title = ""

  private var isCompleted: Bool {
    library.completedTaskIDs.contains(task.id)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        TextField("Title", text: $title)
          .textFieldStyle(.roundedBorder)
          .font(.title3)
          .onSubmit { library.rename(task.id, to: title) }
          .disabled(isCompleted)
        if isCompleted {
          completedLine
        }
        Picker("Priority", selection: priority) {
          Text("None").tag(Priority?.none)
          ForEach(Priority.allCases, id: \.self) { priority in
            Label(priority.title, systemImage: priority.symbol).tag(Priority?.some(priority))
          }
        }
        .disabled(isCompleted)
        Picker("Estimate", selection: estimate) {
          Text("None").tag(Int?.none)
          ForEach(estimateChoices, id: \.self) { minutes in
            Text("\(minutes)m").tag(Int?.some(minutes))
          }
        }
        .disabled(isCompleted)
        if let history = library.estimateHistory(ofTask: task.id) {
          LabeledContent("History", value: history.summary)
        }
        LabeledContent("Project", value: projectTitle)
        NotesView(notes: task.notes, isEditable: !isCompleted) { library.setNotes(task.id, to: $0) }
      }
      .padding(12)
    }
    .frame(width: 300)
    .id(task.id)
    .onAppear { title = task.title }
    .onChange(of: task.title) { _, newTitle in title = newTitle }
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

  private var priority: Binding<Priority?> {
    Binding(get: { task.priority }, set: { library.prioritize(task.id, as: $0) })
  }

  private var estimate: Binding<Int?> {
    Binding(get: { task.estimate }, set: { library.estimate(task.id, as: $0) })
  }

  /// The choices, plus the estimate the task has when it is none of them.
  private var estimateChoices: [Int] {
    Array(Set(Self.estimateChoices + (task.estimate.map { [$0] } ?? []))).sorted()
  }

  private var projectTitle: String {
    task.projectID.flatMap { id in library.knownProjects.first { $0.id == id }?.title } ?? "Inbox"
  }
}

/// The card of the project whose column it heads: title, kind, notes. Its tasks and sub-projects are the
/// list below it. A completed project shows its card too, read-only until it is reopened.
struct ProjectCard: View {
  @Bindable var library: LibraryViewModel
  let project: Project

  @State private var title = ""

  private var isCompleted: Bool {
    library.completedProjectIDs.contains(project.id)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      TextField("Title", text: $title)
        .textFieldStyle(.roundedBorder)
        .font(.title3)
        .onSubmit { library.renameProject(project.id, to: title) }
        .disabled(isCompleted)
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
      Picker("Kind", selection: kind) {
        Label("Parallel", systemImage: ProjectKind.parallel.symbol).tag(ProjectKind.parallel)
        Label("Sequential", systemImage: ProjectKind.sequential.symbol).tag(ProjectKind.sequential)
      }
      .pickerStyle(.segmented)
      .disabled(isCompleted)
      if let history = library.estimateHistory(ofProject: project.id) {
        LabeledContent("History", value: history.summary)
      }
      NotesView(notes: project.notes, isEditable: !isCompleted) { library.setNotes(ofProject: project.id, to: $0) }
    }
    .padding(12)
    .id(project.id)
    .onAppear { title = project.title }
    .onChange(of: project.title) { _, newTitle in title = newTitle }
  }

  private var kind: Binding<ProjectKind> {
    Binding(get: { project.kind }, set: { library.setKind(of: project.id, to: $0) })
  }
}

/// Plain-text notes with their web addresses made clickable. Edit swaps in a text editor; Done saves.
private struct NotesView: View {
  let notes: String?
  let isEditable: Bool
  let save: (String) -> Void

  @State private var isEditing = false
  @State private var draft = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("Notes")
          .font(.headline)
        Spacer()
        if isEditable {
          Button(isEditing ? "Done" : "Edit") { toggle() }
            .buttonStyle(.borderless)
        }
      }
      if isEditing {
        TextEditor(text: $draft)
          .font(.body)
          .frame(minHeight: 120)
          .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.4)))
      } else if let notes {
        Text(Self.linkified(notes))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Text("No notes")
          .foregroundStyle(.secondary)
      }
    }
    .onDisappear {
      if isEditing { save(draft) }
    }
  }

  private func toggle() {
    if isEditing {
      save(draft)
    } else {
      draft = notes ?? ""
    }
    isEditing.toggle()
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
