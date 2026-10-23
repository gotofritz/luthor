import AppKit
import LuthorDomain
import LuthorViewModels
import SwiftUI

/// The settings of the Global family that open a column of their own beside the list.
enum GlobalSettingsDetail: Hashable {
  case dayHours
  case capacity
}

/// A row of the Global settings that opens its settings in the next column.
struct SettingsDetailRow: View {
  let title: String
  let isOpen: Bool
  let open: () -> Void

  var body: some View {
    Button(action: open) {
      HStack {
        Text(title)
        Spacer()
        Image(systemName: "chevron.right")
      }
      .contentShape(.rect)
      .foregroundStyle(isOpen ? Color.accentColor : Color.primary)
    }
    .buttonStyle(.plain)
  }
}

/// The minutes each weekday has, as a list of fields.
struct CapacitySettingsColumn: View {
  @Bindable var library: LibraryViewModel

  var body: some View {
    Form {
      Section("Capacity per weekday, in minutes") {
        ForEach(Weekday.allCases, id: \.self) { weekday in
          HStack {
            Text(weekday.title)
              .lineLimit(1)
            Spacer()
            TextField("Minutes", value: binding(weekday), format: .number)
              .labelsHidden()
              .multilineTextAlignment(.trailing)
              .frame(width: 70)
              .textFieldStyle(.roundedBorder)
          }
        }
      }
    }
    .formStyle(.grouped)
    .frame(width: 280)
  }

  private func binding(_ weekday: Weekday) -> Binding<Int> {
    Binding(
      get: { library.globalSettings.capacity[weekday] ?? weekday.builtInCapacityMinutes },
      set: { library.changeGlobalCapacity(weekday, minutes: min(max($0, 0), 24 * 60)) })
  }
}

/// A drag down one weekday's column, from one quarter-hour row to another.
private struct SliceDrag {
  let weekday: Weekday
  let first: Int
  let last: Int

  /// The quarter hours dragged over, as the hours of a day.
  var hours: DayHours {
    DayHours(start: min(first, last) * 15, end: (max(first, last) + 1) * 15)
  }
}

/// When each weekday starts and ends, drawn on a week of quarter-hour rows: drag down a weekday's column
/// to pick its hours, or click one quarter hour to pick just that. Shift-click or
/// Shift-drag adds to the hours it has.
struct DayHoursSettingsColumn: View {
  @Environment(\.theme) private var theme
  @Bindable var library: LibraryViewModel
  /// The weekday and the rows being dragged over, until the mouse is released.
  @State private var drag: SliceDrag?

  private static let slicesPerDay = 24 * 4
  private static let sliceHeight: CGFloat = 6
  private static let labelWidth: CGFloat = 40

  var body: some View {
    VStack(spacing: 0) {
      Text("Day start and end")
        .font(Theme.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
      headers
      Divider()
      ScrollViewReader { proxy in
        ScrollView {
          HStack(alignment: .top, spacing: 0) {
            hourLabels
            ForEach(Weekday.allCases, id: \.self) { weekday in
              column(weekday)
            }
          }
          .padding(.trailing, 12)
        }
        .onAppear { proxy.scrollTo(7, anchor: .top) }
      }
    }
    .frame(width: 520)
  }

  /// The weekday names, each with its hours, and a way back to nine to five.
  private var headers: some View {
    HStack(spacing: 0) {
      Spacer().frame(width: Self.labelWidth)
      ForEach(Weekday.allCases, id: \.self) { weekday in
        let hours = range(of: weekday)
        VStack(spacing: 2) {
          Text(String(weekday.title.prefix(3)))
            .font(.callout.bold())
          Text("\(clockText(hours.start))–\(clockText(hours.end))")
            .font(.caption2)
            .foregroundStyle(.secondary)
          Button("Reset") { library.resetGlobalDayHours(weekday) }
            .buttonStyle(.link)
            .font(.caption2)
            .help("Back to 09:00–17:00")
        }
        .frame(maxWidth: .infinity)
      }
    }
    .padding(.trailing, 12)
    .padding(.bottom, 6)
  }

  private var hourLabels: some View {
    VStack(spacing: 0) {
      ForEach(0..<24, id: \.self) { hour in
        Text(clockText(hour * 60))
          .font(.caption2)
          .foregroundStyle(.secondary)
          .frame(width: Self.labelWidth, height: Self.sliceHeight * 4, alignment: .top)
          .id(hour)
      }
    }
  }

  /// The hours being dragged out for the weekday, else the ones it has.
  private func range(of weekday: Weekday) -> DayHours {
    if let drag, drag.weekday == weekday {
      return drag.hours
    }
    return library.globalSettings.dayHours[weekday] ?? .builtIn
  }

  private func column(_ weekday: Weekday) -> some View {
    let hours = range(of: weekday)
    return ZStack(alignment: .top) {
      VStack(spacing: 0) {
        ForEach(0..<24, id: \.self) { _ in
          VStack(spacing: 0) {
            Divider()
            Spacer()
          }
          .frame(height: Self.sliceHeight * 4)
        }
      }
      Rectangle()
        .fill(theme.fill.opacity(0.35))
        .frame(height: CGFloat(hours.end - hours.start) / 15 * Self.sliceHeight)
        .frame(maxHeight: .infinity, alignment: .top)
        .offset(y: CGFloat(hours.start) / 15 * Self.sliceHeight)
    }
    .frame(height: Self.sliceHeight * CGFloat(Self.slicesPerDay))
    .frame(maxWidth: .infinity)
    .overlay(alignment: .leading) { Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 1) }
    .contentShape(.rect)
    .gesture(
      DragGesture(minimumDistance: 0)
        .onChanged { value in
          let first = drag?.first ?? slice(at: value.startLocation.y)
          drag = SliceDrag(weekday: weekday, first: first, last: slice(at: value.location.y))
        }
        .onEnded { _ in
          guard let picked = drag else { return }
          drag = nil
          let current = library.globalSettings.dayHours[picked.weekday] ?? .builtIn
          // Shift adds the rows to the hours the weekday has; otherwise they replace them.
          var hours = picked.hours
          if NSEvent.modifierFlags.contains(.shift) {
            hours = DayHours(start: min(current.start, hours.start), end: max(current.end, hours.end))
          }
          library.changeGlobalDayHours(picked.weekday, start: hours.start, end: hours.end)
        })
  }

  private func slice(at height: CGFloat) -> Int {
    min(max(Int(height / Self.sliceHeight), 0), Self.slicesPerDay - 1)
  }
}
