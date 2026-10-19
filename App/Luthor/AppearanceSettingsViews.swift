import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The accent every view falls back to, unless it has its own.
struct GlobalAccentSection: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    Section("Appearance") {
      LabeledContent("Accent: \(library.globalSettings.themeAccent.title)") {
        AccentSwatches(selected: library.globalSettings.themeAccent) { library.changeGlobalAccent($0) }
      }
    }
  }
}

/// The accent of one view: its own once switched on, otherwise the global one.
struct ViewAccentSection: View {
  @Bindable var library: LibraryViewModel
  let viewID: ViewID

  var body: some View {
    Section("Appearance") {
      let accent = library.settings(of: viewID).themeAccent
      let isOverridden = library.isOverridden(.themeAccent, in: viewID)
      Toggle(
        "Accent: \(accent.title)\(isOverridden ? "" : " (global)")",
        isOn: Binding(
          get: { isOverridden },
          set: { library.changeAccent($0 ? accent : nil, for: viewID) })
      )
      if isOverridden {
        AccentSwatches(selected: accent) { library.changeAccent($0, for: viewID) }
      }
    }
  }
}

/// A row of flat colour squares, the one picked marked with a tick.
private struct AccentSwatches: View {
  let selected: ThemeAccent
  let choose: (ThemeAccent) -> Void

  var body: some View {
    HStack(spacing: 6) {
      ForEach(ThemeAccent.allCases, id: \.self) { accent in
        Button {
          choose(accent)
        } label: {
          Rectangle()
            .fill(accent.fill)
            .frame(width: 22, height: 22)
            .overlay {
              if accent == selected {
                Image(systemName: "checkmark")
                  .font(.caption.bold())
                  .foregroundStyle(.white)
              }
            }
        }
        .buttonStyle(.plain)
        .help(accent.title)
      }
    }
  }
}
