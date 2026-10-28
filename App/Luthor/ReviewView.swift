import Foundation
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The Review place: the day shown looked back on. What was done, what was not and wants a decision, the
/// time it took against the estimates, and a one-line note to close the day. The tasks not done share the
/// list selection, so the arrow keys and the Plan menu decide on them.
struct ReviewColumnsView: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    HStack(spacing: 0) {
      DoneColumn(library: library)
      Divider()
      NotDoneColumn(library: library)
    }
  }
}

/// The day shown, its totals and the tasks that were done.
private struct DoneColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    VStack(spacing: 0) {
      PlanReviewToggle(library: library)
        .padding([.horizontal, .top], 12)
        .frame(maxWidth: .infinity, alignment: .leading)
      ReviewHeader(library: library)
      Text(summary)
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.horizontal, .bottom], 12)
      Divider()
      Text("Done")
        .font(Theme.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
      ListSortHeader(
        library: library, listID: "review-done", showsPriority: false, trailingInset: MinutesField.width + 8)
      List {
        ForEach(library.sortedDone, id: \.task.id) { entry in
          ReviewRow(library: library, entry: entry, isDone: true)
        }
      }
    }
    .frame(width: 400)
  }

  /// Planned against logged minutes, and the unplanned ones apart.
  private var summary: String {
    let review = library.review
    return "\(review.estimatedMinutes)m planned, \(review.loggedMinutes)m logged, \(review.unplannedMinutes)m unplanned"
  }
}

/// The tasks planned for the day and not done, each waiting for a decision, and the closing of the review.
private struct NotDoneColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    VStack(spacing: 0) {
      Text("Not done: decide")
        .font(Theme.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
      Divider()
      ListSortHeader(
        library: library, listID: "review-notdone", showsPriority: false, trailingInset: MinutesField.width + 8)
      List(selection: $library.selection) {
        ForEach(library.sortedNotDone, id: \.task.id) { entry in
          ReviewRow(library: library, entry: entry, isDone: false)
            .tag(entry.task.id)
        }
      }
      Divider()
      CloseReviewBox(library: library)
        .id(library.planDate)
    }
    .frame(width: 420)
  }
}

private struct ReviewHeader: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    HStack {
      Button {
        library.showPreviousDay()
      } label: {
        Image(systemName: "chevron.left")
      }
      .help("Previous day")
      Text(title)
        .font(Theme.section)
      Button {
        library.showNextDay()
      } label: {
        Image(systemName: "chevron.right")
      }
      .help("Next day")
      Spacer()
      if library.planDate != library.today {
        Button("Today") { library.showToday() }
      }
      if library.review.isReviewed {
        Label("Reviewed", systemImage: "checkmark.seal.fill")
          .foregroundStyle(.secondary)
      }
    }
    .buttonStyle(.borderless)
    .padding(12)
  }

  private var title: String {
    "\(library.planDate.weekday.title) \(library.planDate.isoString)"
  }
}

/// One task of the review: whether it is done, what it was planned at, the minutes it took, and how the
/// estimates of that kind of work have gone. Completing a task not done moves it to Done.
private struct ReviewRow: View {
  @Bindable var library: LibraryViewModel
  let entry: ReviewEntry
  let isDone: Bool

  var body: some View {
    HStack(spacing: 8) {
      if isDone {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.secondary)
      } else {
        Button {
          library.complete(entry.task.id)
        } label: {
          Image(systemName: "circle")
        }
        .buttonStyle(.plain)
        .help("Complete")
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(entry.task.title)
        if let history = entry.history {
          Text(history.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
      Text(entry.isUnestimated ? "~\(entry.minutes)m" : "\(entry.minutes)m")
        .foregroundStyle(.secondary)
        .frame(width: TaskColumns.duration, alignment: .trailing)
        .help(entry.isUnestimated ? "Unestimated: counted at the default estimate" : "Estimate when first planned")
      MinutesField(minutes: entry.loggedMinutes, prompt: entry.task.estimate == nil ? nil : entry.currentMinutes) {
        library.logTime(entry.task.id, minutes: $0)
      }
      .help("Minutes it took on this day; empty counts its length now")
    }
    .contextMenu {
      if !isDone {
        DecisionMenuItems(library: library, taskID: entry.task.id)
      }
    }
  }
}

/// The unplanned time of the day, its one-line note, and the button that closes the review.
private struct CloseReviewBox: View {
  @Bindable var library: LibraryViewModel
  @State private var note = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Unplanned time")
        Spacer()
        MinutesField(minutes: library.review.unplannedMinutes == 0 ? nil : library.review.unplannedMinutes) {
          library.logUnplannedTime(minutes: $0)
        }
        .help("Minutes spent on work that was not in the plan")
      }
      TextField("One-line note", text: $note)
        .textFieldStyle(.roundedBorder)
        .onSubmit(reviewDay)
      HStack {
        Spacer()
        Button(library.review.isReviewed ? "Update Review" : "Review Day", action: reviewDay)
      }
    }
    .padding(12)
    .onAppear { note = library.review.note ?? "" }
  }

  private func reviewDay() {
    library.reviewDay(note: note)
  }
}

/// A field for minutes entered by hand; an empty field clears them. Text that is not a number is put back
/// as it was.
private struct MinutesField: View {
  let minutes: Int?
  /// What is logged when the review is closed with the field empty, shown greyed in it.
  var prompt: Int?
  let commit: (Int?) -> Void
  @State private var text = ""

  /// How wide the field is, for the header above a column of them.
  static let width: CGFloat = 56

  var body: some View {
    TextField("min", text: $text, prompt: Text(prompt.map(String.init) ?? "min"))
      .textFieldStyle(.roundedBorder)
      .multilineTextAlignment(.trailing)
      .frame(width: Self.width)
      .onSubmit(submit)
      .onAppear { text = shown }
      .onChange(of: minutes) { text = shown }
  }

  private var shown: String {
    minutes.map(String.init) ?? ""
  }

  private func submit() {
    let typed = text.trimmingCharacters(in: .whitespaces)
    if typed.isEmpty {
      commit(nil)
    } else if let value = Int(typed) {
      commit(value)
    } else {
      text = shown
    }
  }
}

extension EstimateHistory {
  /// "Estimated 60m, took 90m (+30m)", over how many tasks when it is more than one.
  var summary: String {
    let sign = differenceMinutes > 0 ? "+" : ""
    let tasks = taskCount > 1 ? " over \(taskCount) tasks" : ""
    return "Estimated \(estimatedMinutes)m, took \(loggedMinutes)m (\(sign)\(differenceMinutes)m)\(tasks)"
  }
}
