import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The columns of the settings place: families of settings in the first, then the individual settings
/// of the one picked (for Views, the list of views and the settings of the one picked). Global settings are the built-in defaults every view falls back to;
/// Views lists every view, and the one picked has overrides of its own, which fall back to the global value
/// when cleared.
struct SettingsColumnsView: View {
  @Bindable var library: LibraryViewModel
  @State private var group = SettingsGroup.global
  @State private var detail: GlobalSettingsDetail?

  var body: some View {
    HStack(spacing: 0) {
      SettingsGroupColumn(selected: $group)
      Divider()
      switch group {
      case .global:
        GlobalSettingsColumn(library: library, detail: $detail)
        if let detail {
          Divider()
          switch detail {
          case .dayHours: DayHoursSettingsColumn(library: library)
          case .capacity: CapacitySettingsColumn(library: library)
          }
        }
      case .views:
        ViewListColumn(library: library)
        Divider()
        ViewSettingsColumn(library: library, viewID: library.viewEdited)
      case .thisMac: ThisMacSettingsColumn()
      }
    }
    // Edit View… in the view switcher opens the settings place on the view picked.
    .onChange(of: library.viewBeingEdited, initial: true) { _, picked in
      if picked != nil { group = .views }
    }
  }
}

/// A family of settings, as the first column of the settings place lists it.
private enum SettingsGroup: Hashable, CaseIterable {
  case global, views, thisMac

  var title: String {
    switch self {
    case .global: "Global"
    case .views: "Views"
    case .thisMac: "This Mac"
    }
  }

  var symbol: String {
    switch self {
    case .global: "globe"
    case .views: "square.stack"
    case .thisMac: "desktopcomputer"
    }
  }
}

private struct SettingsGroupColumn: View {
  @Binding var selected: SettingsGroup

  var body: some View {
    List(selection: $selected) {
      ForEach(SettingsGroup.allCases, id: \.self) { group in
        Label(group.title, systemImage: group.symbol).tag(group)
      }
    }
    .frame(width: 160)
  }
}

/// The settings every view falls back to, unless it overrides them.
private struct GlobalSettingsColumn: View {
  @Bindable var library: LibraryViewModel
  @Binding var detail: GlobalSettingsDetail?

  var body: some View {
    Form {
      Section("Planning") {
        Stepper(
          "Default estimate: \(library.globalSettings.defaultEstimateMinutes)m",
          value: estimateBinding, in: 0...240, step: 5)
        Stepper("Buffer: \(library.globalSettings.bufferPercentage)%", value: bufferBinding, in: 0...100, step: 5)
      }
      Section("New projects") {
        Picker("Priority", selection: projectPriorityBinding) {
          Text("None").tag(Priority?.none)
          ForEach(Priority.allCases, id: \.self) { priority in
            Label(priority.title, systemImage: priority.symbol).tag(Priority?.some(priority))
          }
        }
        Picker("Estimate", selection: projectEstimateBinding) {
          Text("None").tag(Int?.none)
          ForEach(projectEstimateChoices, id: \.self) { minutes in
            Text(EstimateScale.label(minutes)).tag(Int?.some(minutes))
          }
        }
      }
      Section("Weekdays") {
        Stepper(
          "Day changes at: \(clockText(library.globalSettings.dayChangesAt))",
          value: dayChangesBinding, in: 0...Settings.latestDayChangesAt, step: 15)
        SettingsDetailRow(title: "Day start and end", isOpen: detail == .dayHours) { detail = .dayHours }
        SettingsDetailRow(title: "Capacity", isOpen: detail == .capacity) { detail = .capacity }
      }
      Section("Project review") {
        Picker("Review projects", selection: reviewDefaultBinding) {
          ForEach(ReviewInterval.options(including: library.reviewDefault), id: \.self) { interval in
            Text(interval.title).tag(interval)
          }
        }
      }
      GlobalAccentSection(library: library)
      Section("Views") {
        Picker("Default view", selection: defaultViewBinding) {
          ForEach(library.views, id: \.id) { view in
            Text(view.name).tag(view.id)
          }
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 320)
  }

  private var estimateBinding: Binding<Int> {
    Binding(
      get: { library.globalSettings.defaultEstimateMinutes },
      set: { library.changeGlobalSetting(.defaultEstimateMinutes, to: String($0)) })
  }

  private var bufferBinding: Binding<Int> {
    Binding(
      get: { library.globalSettings.bufferPercentage },
      set: { library.changeGlobalSetting(.bufferPercentage, to: String($0)) })
  }

  /// The priority and estimate a new top-level project starts with; the tasks in it start with the same.
  private var projectPriorityBinding: Binding<Priority?> {
    Binding(
      get: { library.globalSettings.defaultProjectPriority },
      set: { library.changeGlobalSetting(.defaultProjectPriority, to: $0?.rawValue) })
  }

  private var projectEstimateBinding: Binding<Int?> {
    Binding(
      get: { library.globalSettings.defaultProjectEstimate },
      set: { library.changeGlobalSetting(.defaultProjectEstimateMinutes, to: $0.map(String.init)) })
  }

  /// The estimates the picker offers, in minutes, and the one set if it is none of them.
  private var projectEstimateChoices: [Int] {
    let chosen = library.globalSettings.defaultProjectEstimate.map { [$0] } ?? []
    return Set([5, 15, 30, 60, 120, 240] + chosen).sorted()
  }

  private var dayChangesBinding: Binding<Int> {
    Binding(
      get: { library.globalSettings.dayChangesAt },
      set: { library.changeGlobalDayChangesAt($0) })
  }

  private var reviewDefaultBinding: Binding<ReviewInterval> {
    Binding(get: { library.reviewDefault }, set: { library.setReviewDefault($0) })
  }

  private var defaultViewBinding: Binding<ViewID> {
    Binding(get: { library.defaultViewID }, set: { library.setDefaultView($0) })
  }
}

/// Every view, to pick the one whose settings the next column shows. Each row carries the view's accent.
private struct ViewListColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    List(selection: picked) {
      ForEach(library.views, id: \.id) { view in
        Label {
          Text(view.name)
        } icon: {
          Rectangle()
            .fill(library.settings(of: view.id).themeAccent.fill)
            .frame(width: 12, height: 12)
        }
        .tag(view.id)
      }
    }
    .frame(width: 160)
  }

  private var picked: Binding<ViewID?> {
    Binding(
      get: { library.viewEdited },
      set: { if let viewID = $0 { library.editView(viewID) } })
  }
}

/// Overrides for one view; off follows the global value.
private struct ViewSettingsColumn: View {
  @Bindable var library: LibraryViewModel
  let viewID: ViewID

  var body: some View {
    Form {
      Section(viewName) {
        Text("Overrides for this view; off follows the global value.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section("Planning") {
        OverridableStepper(
          title: "Buffer", suffix: "%", value: library.settings(of: viewID).bufferPercentage,
          isOverridden: library.isOverridden(.bufferPercentage, in: viewID), range: 0...100, step: 5,
          setOverride: { library.changeSetting(.bufferPercentage, to: $0.map(String.init), for: viewID) })
      }
      ViewAccentSection(library: library, viewID: viewID)
      Section("Capacity per weekday") {
        ForEach(Weekday.allCases, id: \.self) { weekday in
          OverridableStepper(
            title: weekday.title, suffix: "m", value: library.settings(of: viewID).capacity[weekday] ?? 0,
            isOverridden: library.isOverridden(weekday.capacityKey, in: viewID), range: 0...720, step: 15,
            setOverride: { library.changeCapacity(weekday, minutes: $0, for: viewID) })
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 320)
  }

  private var viewName: String {
    library.views.first { $0.id == viewID }?.name ?? ""
  }
}

/// A setting that follows the global value until switched on, then overrides it for this view.
private struct OverridableStepper: View {
  let title: String
  let suffix: String
  /// The resolved value: the override while on, the inherited global value while off.
  let value: Int
  let isOverridden: Bool
  let range: ClosedRange<Int>
  let step: Int
  /// Sets the override; `nil` clears it back to the global value.
  let setOverride: (Int?) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Toggle(
        "\(title): \(value)\(suffix)\(isOverridden ? "" : " (global)")",
        isOn: Binding(get: { isOverridden }, set: { isOn in setOverride(isOn ? value : nil) })
      )
      if isOverridden {
        Stepper("", value: Binding(get: { value }, set: { setOverride($0) }), in: range, step: step)
          .labelsHidden()
      }
    }
  }
}

extension Weekday {
  /// The weekday's name, as the settings place shows it.
  var title: String {
    switch self {
    case .monday: "Monday"
    case .tuesday: "Tuesday"
    case .wednesday: "Wednesday"
    case .thursday: "Thursday"
    case .friday: "Friday"
    case .saturday: "Saturday"
    case .sunday: "Sunday"
    }
  }
}
