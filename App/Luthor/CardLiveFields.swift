import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The fields of the card of an open task or project, each one changed by clicking it and kept at once, with no
/// pencil, OK or Cancel: title, priority as a row of buttons, estimate, due date, repeat and tags, and for a
/// project its kind and how often it is reviewed. The due date shows greyed out with today's date until it is
/// set; picking a day sets it, and the box beside it follows.
struct CardLiveFields: View {
  @Bindable var library: LibraryViewModel
  let id: TaskID
  let isProject: Bool
  let priority: Priority?
  let estimate: Int?
  let title: String
  var kind: ProjectKind = .parallel

  @State private var titleText = ""
  @State private var tagsText = ""
  @State private var didLoad = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      TextField("Title", text: $titleText)
        .textFieldStyle(.roundedBorder)
        .font(.title3)
        .onSubmit(saveTitle)
      if isProject {
        Picker("Kind", selection: kindBinding) {
          Label("Parallel", systemImage: ProjectKind.parallel.symbol).tag(ProjectKind.parallel)
          Label("Sequential", systemImage: ProjectKind.sequential.symbol).tag(ProjectKind.sequential)
        }
        .pickerStyle(.segmented)
      }
      priorityButtons
      EstimateSlider(estimate: estimate) { library.estimate(id, as: $0) }
      dueFields
      RepeatEditor(rule: repeatBinding)
      TextField("Tags", text: $tagsText, prompt: Text("calls, home"))
        .textFieldStyle(.roundedBorder)
        .onSubmit(saveTags)
      if isProject {
        Picker("Review", selection: reviewBinding) {
          Text("Default (\(library.reviewDefault.title))").tag(ReviewInterval?.none)
          ForEach(ReviewInterval.options(including: library.reviewOverride(of: id)), id: \.self) { interval in
            Text(interval.title).tag(ReviewInterval?.some(interval))
          }
        }
      }
    }
    .onAppear(perform: load)
  }

  /// One button for each priority; the one the item has stands out, and a click on it clears the priority.
  private var priorityButtons: some View {
    HStack(spacing: 4) {
      ForEach(Priority.allCases, id: \.self) { option in
        let selected = priority == option
        Button {
          setPriority(selected ? nil : option)
        } label: {
          Label(option.title, systemImage: option.symbol)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(selected ? .accentColor : .secondary)
        .controlSize(.small)
        .help(selected ? "Click again to clear the priority" : "Set the priority")
      }
    }
  }

  private var dueFields: some View {
    let due = library.dueDate(of: id)
    return VStack(alignment: .leading, spacing: 6) {
      HStack {
        Toggle("", isOn: hasDue)
          .labelsHidden()
          .disabled(library.repeatRule(of: id) != nil)
        DatePicker("Due", selection: dueDay, displayedComponents: .date)
          .opacity(due == nil ? 0.5 : 1)
      }
      if due != nil {
        Picker("Kind", selection: dueIsHard) {
          Text("Hard deadline").tag(true)
          Text("Target date").tag(false)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }
    }
  }

  private func load() {
    guard !didLoad else { return }
    didLoad = true
    titleText = title
    tagsText = library.tagItems(of: id).map(\.name).joined(separator: ", ")
  }

  private func saveTitle() {
    if isProject {
      library.renameProject(id, to: titleText)
    } else {
      library.rename(id, to: titleText)
    }
  }

  private func saveTags() {
    library.setTags(id, to: TaskCardDraft.tagNames(in: tagsText))
  }

  private func setPriority(_ priority: Priority?) {
    library.prioritize(id, as: priority)
  }

  private var kindBinding: Binding<ProjectKind> {
    Binding(get: { kind }, set: { library.setKind(of: id, to: $0) })
  }

  private var reviewBinding: Binding<ReviewInterval?> {
    Binding(
      get: { library.reviewOverride(of: id) }, set: { library.setReviewInterval(of: id, to: $0) })
  }

  private var repeatBinding: Binding<RepeatRule?> {
    Binding(get: { library.repeatRule(of: id) }, set: { library.setRepeat(id, to: $0) })
  }

  private var hasDue: Binding<Bool> {
    Binding(
      get: { library.dueDate(of: id) != nil },
      set: { library.setDue(id, to: $0 ? library.today : nil, isHard: dueIsHard.wrappedValue) })
  }

  private var dueDay: Binding<Date> {
    Binding(
      get: { (library.dueDate(of: id)?.date ?? library.today).startOfDay ?? Date() },
      set: { picked in
        guard let day = CalendarDate(dayOf: picked) else { return }
        library.setDue(id, to: day, isHard: dueIsHard.wrappedValue)
      })
  }

  private var dueIsHard: Binding<Bool> {
    Binding(
      get: { library.dueDate(of: id)?.isHard ?? true },
      set: { isHard in
        guard let due = library.dueDate(of: id) else { return }
        library.setDue(id, to: due.date, isHard: isHard)
      })
  }
}
