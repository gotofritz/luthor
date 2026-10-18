import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The weekly review place: the projects whose review is due, the one picked with its card and the buttons to
/// mark it reviewed, put it on hold or drop it, and its tasks, which are listed and edited like any list. The
/// task picked opens its card in the column after.
struct WeeklyReviewColumnsView: View {
  @Bindable var library: LibraryViewModel

  private var picked: Project? {
    library.projectReview.first { $0.project.id == library.reviewProjectID }?.project
  }

  var body: some View {
    HStack(spacing: 0) {
      ReviewProjectColumn(library: library)
      if let project = picked {
        Divider()
        ReviewProjectDetail(library: library, project: project)
        Divider()
        TaskListColumn(library: library)
      }
    }
  }
}

/// The projects due for review, the longest overdue first, each with the day its review fell due.
private struct ReviewProjectColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    List(selection: Binding(get: { library.reviewProjectID }, set: { library.showReviewProject($0) })) {
      ForEach(library.projectReview, id: \.project.id) { item in
        HStack {
          Label(item.project.title, systemImage: item.project.kind.symbol)
            .foregroundStyle(item.project.status == .active ? .primary : .secondary)
          Spacer()
          Text(item.nextReview.isoString)
            .font(.caption)
            .foregroundStyle(.secondary)
            .help("The day the review fell due")
        }
        .tag(item.project.id)
      }
    }
    .overlay {
      if library.projectReview.isEmpty {
        Text("Nothing to review.")
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding()
      }
    }
    .frame(width: 260)
  }
}

/// The card of the project picked, and what to do with it.
private struct ReviewProjectDetail: View {
  @Bindable var library: LibraryViewModel
  let project: Project

  var body: some View {
    VStack(spacing: 0) {
      ProjectCard(library: library, project: project)
      Divider()
      VStack(alignment: .leading, spacing: 10) {
        Button("Mark Reviewed", systemImage: "checkmark.circle") { library.markProjectReviewed() }
          .help("Mark this project reviewed and pick the next one (⇧⌘R)")
        Picker("Review", selection: ownInterval) {
          Text("Default (\(library.reviewDefault.title))").tag(ReviewInterval?.none)
          ForEach(ReviewInterval.options(including: library.reviewOverride(of: project.id)), id: \.self) { interval in
            Text(interval.title).tag(ReviewInterval?.some(interval))
          }
        }
        ProjectStatusButtons(library: library, project: project)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      Spacer()
    }
    .frame(width: 280)
  }

  /// The interval the project has of its own; `nil` while it follows the default.
  private var ownInterval: Binding<ReviewInterval?> {
    Binding(
      get: { library.reviewOverride(of: project.id) },
      set: { library.setReviewInterval(of: project.id, to: $0) })
  }
}

/// Put on hold, resume, drop: the buttons that fit the status the project has.
private struct ProjectStatusButtons: View {
  @Bindable var library: LibraryViewModel
  let project: Project

  var body: some View {
    HStack {
      if project.status == .active {
        Button("Put on Hold", systemImage: ProjectStatus.onHold.symbol) { library.putOnHold(project.id) }
      } else {
        Button("Resume", systemImage: "play.circle") { library.resume(project.id) }
      }
      if project.status != .dropped {
        Button("Drop", systemImage: ProjectStatus.dropped.symbol) { library.dropProject(project.id) }
      }
    }
  }
}

/// The review items of a project's context menu: how often it is reviewed, and its status.
struct ProjectReviewMenuItems: View {
  @Bindable var library: LibraryViewModel
  let project: Project

  var body: some View {
    Menu("Review") {
      Button("Default (\(library.reviewDefault.title))") { library.setReviewInterval(of: project.id, to: nil) }
        .disabled(library.reviewOverride(of: project.id) == nil)
      ForEach(ReviewInterval.options(including: library.reviewOverride(of: project.id)), id: \.self) { interval in
        Button(interval.title) { library.setReviewInterval(of: project.id, to: interval) }
          .disabled(library.reviewOverride(of: project.id) == interval)
      }
    }
    if project.status == .active {
      Button("Put on Hold") { library.putOnHold(project.id) }
    } else {
      Button("Resume") { library.resume(project.id) }
    }
    if project.status != .dropped {
      Button("Drop Project") { library.dropProject(project.id) }
    }
  }
}

extension ReviewInterval {
  /// The intervals offered next to "off", in days.
  private static let choices = [1, 3, 7, 14, 30]

  /// Off, then the usual intervals, then `extra` when it is none of them, shortest first.
  static func options(including extra: ReviewInterval? = nil) -> [ReviewInterval] {
    var days = choices
    if let extraDays = extra?.days, !days.contains(extraDays) { days.append(extraDays) }
    return [.off] + days.sorted().map { ReviewInterval.every(days: $0) }
  }

  /// "Off", "Daily", "Weekly" or "Every 3 days".
  var title: String {
    switch days {
    case nil: "Off"
    case 1?: "Daily"
    case 7?: "Weekly"
    case let days?: "Every \(days) days"
    }
  }
}

extension ProjectStatus {
  /// "Active", "On hold" or "Dropped".
  var title: String {
    switch self {
    case .active: "Active"
    case .onHold: "On hold"
    case .dropped: "Dropped"
    }
  }

  /// The SF Symbol of the status.
  var symbol: String {
    switch self {
    case .active: "play.circle"
    case .onHold: "pause.circle"
    case .dropped: "xmark.circle"
    }
  }
}
