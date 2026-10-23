import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The Tags place's first column: the view's tags, each with how many open tasks carry it. A click picks one,
/// and the next column lists its tasks. Tags are made on a task's card, so this list has no capture field.
struct TagColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    List(selection: Binding(get: { library.selectedTagID }, set: { library.showTag($0) })) {
      ForEach(library.tags) { item in
        HStack {
          Label(item.name, systemImage: "tag")
          Spacer()
          Text("\(library.tagTaskCounts[item.id] ?? 0)")
            .foregroundStyle(.secondary)
        }
        .tag(item.id)
      }
    }
    .overlay {
      if library.tags.isEmpty {
        Text("No tags yet. Add one on a task's card.")
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding()
      }
    }
    .frame(width: 220)
  }
}

/// The tags of a task as the lists and the read-only card show them: `@calls @home`; `nil` for a task with none.
func tagLine(of tags: [TagItem]) -> String? {
  tags.isEmpty ? nil : tags.map { "@\($0.name)" }.joined(separator: " ")
}

/// A menu that narrows Today's candidates: by tag (several narrow further), priority, project and deadline.
struct CandidateFilterMenu: View {
  @Bindable var library: LibraryViewModel

  private var filterSymbol: String {
    library.candidateFilter.isEmpty
      ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
  }

  var body: some View {
    Menu {
      Menu("Tag") {
        ForEach(library.tags) { item in
          Button {
            library.toggleCandidateTag(item.id)
          } label: {
            if library.candidateFilter.tags.contains(item.id) {
              Label(item.name, systemImage: "checkmark")
            } else {
              Text(item.name)
            }
          }
        }
      }
      .disabled(library.tags.isEmpty)
      Picker("Priority", selection: $library.candidateFilter.priority) {
        Text("Any").tag(Priority?.none)
        ForEach(Priority.allCases, id: \.self) { priority in
          Text("\(priority.icon) \(priority.title)").tag(Priority?.some(priority))
        }
      }
      Picker("Project", selection: $library.candidateFilter.projectID) {
        Text("Any").tag(TaskID?.none)
        ForEach(library.projects, id: \.id) { project in
          Text(project.title).tag(TaskID?.some(project.id))
        }
      }
      Picker("Deadline", selection: $library.candidateFilter.dueBy) {
        Text("Any").tag(CalendarDate?.none)
        Text("Due by the day shown").tag(CalendarDate?.some(library.planDate))
        Text("Due within a week").tag(CalendarDate?.some(library.planDate.adding(days: 7)))
      }
      Divider()
      Button("Clear Filter") { library.candidateFilter = TaskFilter() }
        .disabled(library.candidateFilter.isEmpty)
    } label: {
      Label("Filter", systemImage: filterSymbol)
    }
    .menuStyle(.borderlessButton)
    .fixedSize()
    .help("Narrow the candidates")
  }
}
