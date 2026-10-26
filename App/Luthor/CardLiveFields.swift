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

  @Environment(\.theme) private var theme
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
      RepeatEditor(rule: repeatBinding, hasDue: library.dueDate(of: id) != nil)
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
        if let next = library.nextReviewDate(of: id), library.reviewInterval(of: id) != .off {
          DatePicker("Next review", selection: nextReviewBinding(next), displayedComponents: .date)
        }
      }
    }
    .onAppear(perform: load)
  }

  /// One button for each priority; the one the item has stands out on the accent's background, and a click on it
  /// clears the priority.
  private var priorityButtons: some View {
    HStack(spacing: 4) {
      ForEach(Priority.allCases, id: \.self) { option in
        let selected = priority == option
        Button {
          setPriority(selected ? nil : option)
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
        .accessibilityLabel(option.title)
      }
    }
  }

  private var dueFields: some View {
    let due = library.dueDate(of: id)
    return VStack(alignment: .leading, spacing: 6) {
      HStack {
        Toggle("", isOn: hasDue)
          .labelsHidden()
        DatePicker("Due", selection: dueDay, displayedComponents: .date)
          .opacity(due == nil ? 0.5 : 1)
      }
      .contentShape(.rect)
      .onTapGesture {
        if due == nil { library.setDue(id, to: library.today, isHard: false) }
      }
      if !isProject {
        HStack {
          Toggle("", isOn: isScheduled)
            .labelsHidden()
          DatePicker("Scheduled", selection: scheduledDay, displayedComponents: .date)
            .opacity(library.scheduledDate(of: id) == nil ? 0.5 : 1)
        }
        .contentShape(.rect)
        .onTapGesture {
          if library.scheduledDate(of: id) == nil { library.schedule(id, on: library.today) }
        }
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

  private func nextReviewBinding(_ next: CalendarDate) -> Binding<Date> {
    Binding(
      get: { next.startOfDay ?? Date() },
      set: { picked in
        guard let day = CalendarDate(dayOf: picked) else { return }
        library.setNextReview(of: id, to: day)
      })
  }

  private var repeatBinding: Binding<RepeatRule?> {
    Binding(get: { library.repeatRule(of: id) }, set: { library.setRepeat(id, to: $0) })
  }

  private var hasDue: Binding<Bool> {
    Binding(
      get: { library.dueDate(of: id) != nil },
      set: {
        if $0 {
          library.setDue(id, to: library.today, isHard: false)
        } else {
          library.clearDue(id)
        }
      })
  }

  private var dueDay: Binding<Date> {
    Binding(
      get: { (library.dueDate(of: id)?.date ?? library.today).startOfDay ?? Date() },
      set: { picked in
        guard let day = CalendarDate(dayOf: picked) else { return }
        library.setDue(id, to: day, isHard: false)
      })
  }

  private var isScheduled: Binding<Bool> {
    Binding(
      get: { library.scheduledDate(of: id) != nil },
      set: {
        if $0 {
          library.schedule(id, on: library.today)
        } else {
          library.removeFromPlan(id)
        }
      })
  }

  private var scheduledDay: Binding<Date> {
    Binding(
      get: { (library.scheduledDate(of: id) ?? library.today).startOfDay ?? Date() },
      set: { picked in
        guard let day = CalendarDate(dayOf: picked) else { return }
        library.schedule(id, on: day)
      })
  }
}
