import LuthorDomain
import LuthorViewModels
import SwiftUI

extension RepeatRule.Unit {
  /// The unit as the repeat editor's picker lists it.
  var plural: String {
    rawValue.capitalized + "s"
  }
}

/// How a task repeats, on its card: "Repeats every week on Mon, Thu".
struct RepeatLine: View {
  let rule: RepeatRule

  var body: some View {
    Label(rule.summary, systemImage: "repeat")
      .font(.callout)
  }
}

/// The Repeat field of a task card in edit mode: whether the task repeats, every how many days, weeks, months or
/// years, on which weekdays, and counted from the due date or from the day it is done.
struct RepeatEditor: View {
  @Binding var rule: RepeatRule?
  /// Whether the item has a due date. Without one a repeat can only count from the day the item is done.
  var hasDue = true

  /// What the controls show while the item does not repeat: greyed out, and any of them switches Repeat on with it.
  private var placeholder: RepeatRule {
    RepeatRule(every: 1, unit: .week, afterCompletion: !hasDue)
  }

  var body: some View {
    let current = rule ?? placeholder
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Toggle("Repeat every", isOn: isRepeating)
        Group {
          Stepper("\(current.every)", value: every(of: current), in: 1...99)
            .fixedSize()
          Picker("", selection: unit(of: current)) {
            ForEach(RepeatRule.Unit.allCases, id: \.self) { unit in
              Text(unit.plural).tag(unit)
            }
          }
          .labelsHidden()
          .fixedSize()
        }
        .opacity(rule == nil ? 0.5 : 1)
      }
      Group {
        if current.unit == .week && !current.afterCompletion {
          HStack(spacing: 4) {
            ForEach(Weekday.allCases, id: \.self) { day in
              Toggle(String(day.abbreviation.prefix(2)), isOn: weekday(day, of: current))
                .toggleStyle(.button)
            }
          }
          .help("The days of the week; none repeats on the weekday of the due date")
        }
        HStack(spacing: 4) {
          ForEach([false, true], id: \.self) { after in
            Button(after ? "After it is done" : "From the due date") {
              afterCompletion(of: current).wrappedValue = after
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(current.afterCompletion == after ? .accentColor : .secondary)
            .disabled(!after && !hasDue)
          }
        }
        if rule != nil {
          Text(current.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .opacity(rule == nil ? 0.5 : 1)
    }
  }

  private var isRepeating: Binding<Bool> {
    Binding(
      get: { rule != nil },
      set: { rule = $0 ? placeholder : nil })
  }

  private func every(of current: RepeatRule) -> Binding<Int> {
    Binding(
      get: { current.every },
      set: {
        rule = RepeatRule(
          every: $0, unit: current.unit, weekdays: current.weekdays, afterCompletion: current.afterCompletion)
      })
  }

  private func unit(of current: RepeatRule) -> Binding<RepeatRule.Unit> {
    Binding(
      get: { current.unit },
      set: {
        rule = RepeatRule(
          every: current.every, unit: $0, weekdays: current.weekdays, afterCompletion: current.afterCompletion)
      })
  }

  private func afterCompletion(of current: RepeatRule) -> Binding<Bool> {
    Binding(
      get: { current.afterCompletion },
      set: {
        rule = RepeatRule(every: current.every, unit: current.unit, weekdays: current.weekdays, afterCompletion: $0)
      })
  }

  private func weekday(_ day: Weekday, of current: RepeatRule) -> Binding<Bool> {
    Binding(
      get: { current.weekdays.contains(day) },
      set: { isOn in
        var days = current.weekdays
        if isOn { days.insert(day) } else { days.remove(day) }
        rule = RepeatRule(
          every: current.every, unit: current.unit, weekdays: days, afterCompletion: current.afterCompletion)
      })
  }
}

/// The Repeat submenu of a task's context menu: a rule to start with, and for a task that repeats skipping this
/// one and stopping. The card's editor offers the rest.
struct RepeatMenuItems: View {
  @Bindable var library: LibraryViewModel
  let taskID: TaskID

  var body: some View {
    Menu("Repeat") {
      ForEach(RepeatRule.Unit.allCases, id: \.self) { unit in
        Button("Every \(unit.rawValue.capitalized)") {
          library.setRepeat(taskID, to: RepeatRule(every: 1, unit: unit))
        }
      }
      if library.repeatRule(of: taskID) != nil {
        Divider()
        Button("Skip This One") { library.skip(taskID) }
        Button("Stop Repeating") { library.stopRepeating(taskID) }
      }
    }
  }
}
