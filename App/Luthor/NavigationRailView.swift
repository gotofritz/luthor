import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The narrow strip on the left: one button for each place, an icon with its name underneath. It never
/// expands. A new place gets a new case in `NavigationSection` and its icon here.
struct NavigationRailView: View {
  @Bindable var library: LibraryViewModel

  /// Places listed above the settings icon, which is pinned to the bottom instead.
  private static let mainSections = NavigationSection.allCases.filter { $0 != .settings }

  var body: some View {
    VStack(spacing: 4) {
      ForEach(Self.mainSections, id: \.self) { section in
        RailButton(library: library, section: section)
      }
      Spacer()
      RailButton(library: library, section: .settings)
    }
    .padding(6)
    .frame(width: 72)
    .background(.bar)
  }
}

/// One icon-and-name button of the rail, for the place it leads to.
private struct RailButton: View {
  @Bindable var library: LibraryViewModel
  let section: NavigationSection

  var body: some View {
    Button {
      library.show(section)
    } label: {
      VStack(spacing: 2) {
        Image(systemName: section.symbol)
          .font(.title2)
        Text(section.title)
          .font(.caption)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 6)
      .background(library.section == section ? Color.accentColor.opacity(0.2) : .clear, in: .rect(cornerRadius: 6))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .foregroundStyle(library.section == section ? Color.accentColor : .secondary)
    .help(section.title)
  }
}

extension NavigationSection {
  /// The SF Symbol the rail shows for the place.
  var symbol: String {
    switch self {
    case .inbox: "tray"
    case .today: "sun.max"
    case .projects: "folder"
    case .priorities: "flag"
    case .settings: "gear"
    }
  }

  var title: String {
    switch self {
    case .inbox: "Inbox"
    case .today: "Today"
    case .projects: "Projects"
    case .priorities: "Prios"
    case .settings: "Settings"
    }
  }
}

extension Priority {
  var title: String {
    switch self {
    case .critical: "Critical"
    case .important: "Important"
    case .optional: "Optional"
    case .someday: "One day"
    }
  }

  /// The SF Symbol of the flag, filled more the more urgent the priority is.
  var symbol: String {
    switch self {
    case .critical: "flag.fill"
    case .important: "flag"
    case .optional: "flag.slash"
    case .someday: "moon.zzz"
    }
  }
}
