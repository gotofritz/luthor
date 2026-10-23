import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// What the card of a task or a project lets one set besides its title and notes, until OK keeps it.
struct CardFields {
  var priority: Priority?
  var estimate: Int?
  var hasDue: Bool
  var dueDay: Date
  var repeatRule: RepeatRule?
  var tagsText: String

  @MainActor
  init(library: LibraryViewModel, id: TaskID, priority: Priority?, estimate: Int?) {
    self.priority = priority
    self.estimate = estimate
    let due = library.dueDate(of: id)
    hasDue = due != nil
    dueDay = due?.date.startOfDay ?? Date()
    repeatRule = library.repeatRule(of: id)
    tagsText = library.tagItems(of: id).map(\.name).joined(separator: ", ")
  }

  /// The fields of an item that does not exist yet, so with no due date, repeat or tags.
  init(priority: Priority?, estimate: Int?) {
    self.priority = priority
    self.estimate = estimate
    hasDue = false
    dueDay = Date()
    repeatRule = nil
    tagsText = ""
  }

  func draft(title: String, notes: String) -> TaskCardDraft {
    let due = hasDue ? CalendarDate(dayOf: dueDay).map { DueDate(date: $0, isHard: false) } : nil
    return TaskCardDraft(
      title: title, priority: priority, estimate: estimate, due: due, notes: notes,
      tags: TaskCardDraft.tagNames(in: tagsText), repeatRule: repeatRule)
  }
}

/// The priority, estimate, due date, repeat and tags of a card in edit mode: the same for a task and a project.
struct CardFieldsForm: View {
  let library: LibraryViewModel
  @Binding var fields: CardFields
  let submit: () -> Void

  var body: some View {
    Picker("Priority", selection: $fields.priority) {
      Text("None").tag(Priority?.none)
      ForEach(Priority.allCases, id: \.self) { priority in
        Label(priority.title, systemImage: priority.symbol).tag(Priority?.some(priority))
      }
    }
    EstimateSlider(estimate: fields.estimate) { fields.estimate = $0 }
    Toggle("Due date", isOn: $fields.hasDue)
    if fields.hasDue {
      DatePicker("Due", selection: $fields.dueDay, displayedComponents: .date)
    }
    RepeatEditor(rule: $fields.repeatRule, hasDue: fields.hasDue)
    tagsField
  }

  /// The tags as typed, separated by commas, and a menu to add one the view already has.
  private var tagsField: some View {
    HStack {
      TextField("Tags", text: $fields.tagsText, prompt: Text("calls, home"))
        .textFieldStyle(.roundedBorder)
        .onSubmit(submit)
      Menu {
        ForEach(library.tags) { item in
          Button(item.name) {
            fields.tagsText = (TaskCardDraft.tagNames(in: fields.tagsText) + [item.name]).joined(separator: ", ")
          }
        }
      } label: {
        Image(systemName: "tag")
      }
      .menuStyle(.borderlessButton)
      .fixedSize()
      .disabled(library.tags.isEmpty)
      .help("Add a tag")
    }
  }
}
