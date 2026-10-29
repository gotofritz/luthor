import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The card of several tasks selected together. A field shows its value only where all of them agree, and is
/// greyed where they differ; setting any field applies it to every task, as one step to undo.
struct BulkCardColumn: View {
  @Bindable var library: LibraryViewModel
  let summary: BulkSummary

  @Environment(\.theme) private var theme
  @State private var tagText = ""
  @State private var confirmingDelete = false

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        Text("\(summary.count) tasks")
          .font(.title3)
        projectPicker
        tagFields
        priorityButtons
        EstimateSlider(estimate: shared(summary.estimate)) { library.applyBulk(BulkEdit(estimate: .set($0))) }
          .opacity(summary.estimate == .mixed ? 0.5 : 1)
        dueFields
        Divider()
        actions
      }
      .padding(12)
    }
    .frame(width: 300)
  }

  /// The value all the tasks have, `nil` where they differ or none has one.
  private func shared<Value>(_ common: Common<Value?>) -> Value? {
    if case .same(let value) = common { return value }
    return nil
  }

  private var projectPicker: some View {
    let binding = Binding<TaskID?>(
      get: { shared(summary.project) },
      set: { library.applyBulk(BulkEdit(project: .set($0))) })
    return Picker("Project", selection: binding) {
      if summary.project == .mixed { Text("Mixed").tag(TaskID?.none) } else { Text("None").tag(TaskID?.none) }
      ForEach(library.projectOutline()) { entry in
        Text(String(repeating: "  ", count: entry.depth) + entry.title).tag(TaskID?.some(entry.id))
      }
    }
    .opacity(summary.project == .mixed ? 0.5 : 1)
  }

  /// The tags all carry, each with a button that takes it off every task; the ones only some carry, greyed, that
  /// a click puts on all; and a field that puts a tag on all.
  private var tagFields: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(summary.commonTags) { tag in
        Button {
          library.untagSelected(tag.id)
        } label: {
          Label(tag.name, systemImage: "xmark.circle.fill")
        }
        .buttonStyle(.borderless)
        .help("Take \(tag.name) off every task")
      }
      ForEach(summary.partialTags) { tag in
        Button {
          library.tagSelected(named: tag.name)
        } label: {
          Label(tag.name, systemImage: "plus.circle")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help("Only some tasks carry \(tag.name): put it on all")
      }
      HStack(spacing: 6) {
        Image(systemName: "tag")
          .foregroundStyle(.secondary)
        TextField("Add a tag", text: $tagText)
          .textFieldStyle(.roundedBorder)
          .onSubmit {
            library.tagSelected(named: tagText)
            tagText = ""
          }
      }
    }
  }

  private var priorityButtons: some View {
    HStack(spacing: 4) {
      ForEach(Priority.allCases, id: \.self) { option in
        let selected = shared(summary.priority) == option
        Button {
          library.applyBulk(BulkEdit(priority: .set(selected ? nil : option)))
        } label: {
          Image(systemName: option.symbol)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 3)
            .foregroundStyle(selected ? Color.white : Color.secondary)
            .background(selected ? theme.fill : Color.secondary.opacity(0.12), in: .rect(cornerRadius: 5))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(option.title)
        .accessibilityLabel(option.title)
      }
    }
    .opacity(summary.priority == .mixed ? 0.5 : 1)
  }

  private var dueFields: some View {
    let due = shared(summary.due)
    let day = Binding<Date>(
      get: { (due?.date ?? library.today).startOfDay ?? Date() },
      set: { picked in
        guard let date = CalendarDate(dayOf: picked) else { return }
        library.applyBulk(BulkEdit(due: .set(DueDate(date: date, isHard: due?.isHard ?? false))))
      })
    return HStack {
      Toggle(
        "",
        isOn: Binding(
          get: { due != nil },
          set: { isOn in
            let value = isOn ? DueDate(date: library.today, isHard: false) : nil
            library.applyBulk(BulkEdit(due: .set(value)))
          })
      )
      .labelsHidden()
      DatePicker("Due", selection: day, displayedComponents: .date)
        .opacity(due == nil ? 0.5 : 1)
    }
  }

  private var actions: some View {
    HStack {
      Button("Drop") { library.dropSelectedTasks() }
      Button("Delete…", role: .destructive) { confirmingDelete = true }
    }
    .confirmationDialog("Delete \(summary.count) tasks for good?", isPresented: $confirmingDelete) {
      Button("Delete", role: .destructive) { library.deleteSelectedTasks() }
    }
  }
}
