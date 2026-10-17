import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The narrow strip on the left: one button for each place, an icon with its name underneath. It never
/// expands. A new place gets a new case in `NavigationSection` and its icon here.
struct NavigationRailView: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    VStack(spacing: 4) {
      ForEach(NavigationSection.allCases, id: \.self) { section in
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
      Spacer()
    }
    .padding(6)
    .frame(width: 72)
    .background(.bar)
  }
}

extension NavigationSection {
  /// The SF Symbol the rail shows for the place.
  var symbol: String {
    switch self {
    case .inbox: "tray"
    case .projects: "folder"
    case .priorities: "flag"
    }
  }

  var title: String {
    switch self {
    case .inbox: "Inbox"
    case .projects: "Projects"
    case .priorities: "Prios"
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
