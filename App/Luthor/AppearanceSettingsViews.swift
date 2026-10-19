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

/// The accent of the view shown: its own once switched on, otherwise the global one.
struct LocalAccentSection: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    Section("Appearance") {
      let accent = library.viewSettings.themeAccent
      let isOverridden = library.isOverriddenForCurrentView(.themeAccent)
      Toggle(
        "Accent: \(accent.title)\(isOverridden ? "" : " (global)")",
        isOn: Binding(
          get: { isOverridden },
          set: { library.changeAccentForCurrentView($0 ? accent : nil) })
      )
      if isOverridden {
        AccentSwatches(selected: accent) { library.changeAccentForCurrentView($0) }
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
