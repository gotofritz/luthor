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
  var hasScheduled = false
  var scheduledDay = Date()
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
      tags: TaskCardDraft.tagNames(in: tagsText), repeatRule: repeatRule,
      scheduled: hasScheduled ? CalendarDate(dayOf: scheduledDay) : nil)
  }
}

/// The tags, priority, estimate, due date and repeat of a card in edit mode: the same for a task and a project.
struct CardFieldsForm: View {
  let library: LibraryViewModel
  @Binding var fields: CardFields
  let submit: () -> Void
  /// Whether the item can be planned for a day: a task, not a project.
  var canSchedule = true

  @Environment(\.theme) private var theme

  /// One button for each priority; the one the item has stands out on the accent's background, and a click on it
  /// clears the priority.
  private var priorityButtons: some View {
    HStack(spacing: 4) {
      ForEach(Priority.allCases, id: \.self) { option in
        let selected = fields.priority == option
        Button {
          fields.priority = selected ? nil : option
        } label: {
          Image(systemName: option.symbol)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .foregroundStyle(selected ? Color.white : Color.secondary)
            .background(selected ? theme.fill : Color.secondary.opacity(0.12), in: .rect(cornerRadius: 5))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(selected ? "\(option.title): click again to clear" : option.title)
      }
    }
  }

  var body: some View {
    tagsField
    priorityButtons
    EstimateSlider(estimate: fields.estimate) { fields.estimate = $0 }
    HStack {
      Toggle("", isOn: $fields.hasDue)
        .labelsHidden()
      DatePicker("Due", selection: dueDay, displayedComponents: .date)
        .opacity(fields.hasDue ? 1 : 0.5)
    }
    .contentShape(.rect)
    .onTapGesture { fields.hasDue = true }
    if canSchedule {
      HStack {
        Toggle("", isOn: $fields.hasScheduled)
          .labelsHidden()
        DatePicker("Scheduled", selection: scheduledDay, displayedComponents: .date)
          .opacity(fields.hasScheduled ? 1 : 0.5)
      }
      .contentShape(.rect)
      .onTapGesture { fields.hasScheduled = true }
    }
    RepeatEditor(rule: $fields.repeatRule, hasDue: fields.hasDue)
  }

  /// Picking a day ticks the box, as clicking the row does.
  private var dueDay: Binding<Date> {
    Binding(
      get: { fields.dueDay },
      set: {
        fields.dueDay = $0
        fields.hasDue = true
      })
  }

  private var scheduledDay: Binding<Date> {
    Binding(
      get: { fields.scheduledDay },
      set: {
        fields.scheduledDay = $0
        fields.hasScheduled = true
      })
  }

  /// The tags as typed, separated by commas, after the tag icon, which is also the menu that adds one the view
  /// already has. Just under the title, so they are not taken for notes.
  private var tagsField: some View {
    HStack(spacing: 6) {
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
      TextField("Tags", text: $fields.tagsText, prompt: Text("calls, home"))
        .textFieldStyle(.roundedBorder)
        .onSubmit(submit)
    }
  }
}
