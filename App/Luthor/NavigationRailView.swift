import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The narrow strip on the left: one button for each place, an icon with its name underneath. It never
/// expands. A new place gets a new case in `NavigationSection` and its icon here.
struct NavigationRailView: View {
  @Bindable var library: LibraryViewModel

  /// Places listed above the settings icon, which is pinned to the bottom instead. The day's review has no
  /// icon of its own: it is Today's other face, picked with the toggle in its header.
  private static let mainSections = NavigationSection.allCases.filter { $0 != .settings && $0 != .review }

  @Environment(\.theme) private var theme

  var body: some View {
    VStack(spacing: 0) {
      LuthorMark()
        .frame(maxWidth: .infinity)
        .padding(.top, 25)
      VStack(spacing: 4) {
        ForEach(Self.mainSections, id: \.self) { section in
          RailButton(library: library, section: section)
        }
        Spacer()
        RailButton(library: library, section: .settings)
      }
      .padding(6)
      .padding(.top, 14)
      .frame(maxHeight: .infinity)
      .background(LuthorMark.shadow)
    }
    .frame(width: 72)
    .background(theme.fill)
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
      .background(isPicked ? Color.white.opacity(0.22) : .clear, in: .rect(cornerRadius: 2))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .foregroundStyle(isPicked ? Color.white : Color.white.opacity(0.65))
    .help(section.title)
  }

  /// The place shown; Today stays picked while its review is shown.
  private var isPicked: Bool {
    library.section == section || (section == .today && library.section == .review)
  }
}

extension NavigationSection {
  /// The SF Symbol the rail shows for the place.
  var symbol: String {
    switch self {
    case .inbox: "tray"
    case .today: "sun.max"
    case .calendar: "calendar"
    case .review: "checklist"
    case .weeklyReview: "eyeglasses"
    case .projects: "folder"
    case .priorities: "flag"
    case .tags: "tag"
    case .settings: "gear"
    }
  }

  var title: String {
    switch self {
    case .inbox: "Inbox"
    case .today: "Today"
    case .calendar: "Calendar"
    case .review: "Review"
    case .weeklyReview: "Reviews"
    case .projects: "Projects"
    case .priorities: "Prios"
    case .tags: "Tags"
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
