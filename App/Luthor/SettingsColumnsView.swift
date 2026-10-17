import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The two columns of the settings place: families of settings in the first, the individual settings
/// of the one picked in the second. Global settings are the built-in defaults every view falls back to;
/// Local settings are overrides for the view currently shown, which fall back to the global value when
/// cleared.
struct SettingsColumnsView: View {
  @Bindable var library: LibraryViewModel
  @State private var group = SettingsGroup.global

  var body: some View {
    HStack(spacing: 0) {
      SettingsGroupColumn(selected: $group)
      Divider()
      switch group {
      case .global: GlobalSettingsColumn(library: library)
      case .local: LocalSettingsColumn(library: library)
      }
    }
  }
}

/// A family of settings, as the first column of the settings place lists it.
private enum SettingsGroup: Hashable, CaseIterable {
  case global, local

  var title: String {
    switch self {
    case .global: "Global"
    case .local: "Local"
    }
  }

  var symbol: String {
    switch self {
    case .global: "globe"
    case .local: "pin"
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

  var body: some View {
    Form {
      Section("Planning") {
        Stepper(
          "Default estimate: \(library.globalSettings.defaultEstimateMinutes)m",
          value: estimateBinding, in: 0...240, step: 5)
        Stepper("Buffer: \(library.globalSettings.bufferPercentage)%", value: bufferBinding, in: 0...100, step: 5)
      }
      Section("Capacity per weekday") {
        ForEach(Weekday.allCases, id: \.self) { weekday in
          Stepper(
            "\(weekday.title): \(library.globalSettings.capacity[weekday] ?? 0)m",
            value: capacityBinding(weekday), in: 0...720, step: 15)
        }
      }
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

  private func capacityBinding(_ weekday: Weekday) -> Binding<Int> {
    Binding(
      get: { library.globalSettings.capacity[weekday] ?? weekday.builtInCapacityMinutes },
      set: { library.changeGlobalCapacity(weekday, minutes: $0) })
  }

  private var defaultViewBinding: Binding<ViewID> {
    Binding(get: { library.defaultViewID }, set: { library.setDefaultView($0) })
  }
}

/// Overrides for the view currently shown; blank follows the global value.
private struct LocalSettingsColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    Form {
      Section(currentViewName) {
        Text("Overrides for this view; off follows the global value.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Section("Planning") {
        OverridableStepper(
          title: "Buffer", suffix: "%", value: library.viewSettings.bufferPercentage,
          isOverridden: library.isOverriddenForCurrentView(.bufferPercentage), range: 0...100, step: 5,
          setOverride: { library.changeSettingForCurrentView(.bufferPercentage, to: $0.map(String.init)) })
      }
      Section("Capacity per weekday") {
        ForEach(Weekday.allCases, id: \.self) { weekday in
          OverridableStepper(
            title: weekday.title, suffix: "m", value: library.viewSettings.capacity[weekday] ?? 0,
            isOverridden: library.isCapacityOverriddenForCurrentView(weekday), range: 0...720, step: 15,
            setOverride: { library.changeCapacityForCurrentView(weekday, minutes: $0) })
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 320)
  }

  private var currentViewName: String {
    library.views.first { $0.id == library.currentView }?.name ?? ""
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
