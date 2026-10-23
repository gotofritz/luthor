import LuthorViewModels
import SwiftUI

/// The Estimate field of a card: a logarithmic slider from 5 minutes to a week that takes any value in between.
/// The estimate is handed on when the slider is let go, not on every step of the drag; the button beside it
/// clears the estimate.
struct EstimateSlider: View {
  let estimate: Int?
  let commit: (Int?) -> Void

  @State private var position = 0.0
  @State private var isDragging = false

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text("Estimate")
        Spacer()
        Text(shown.map(EstimateScale.label) ?? "None")
          .foregroundStyle(.secondary)
          .monospacedDigit()
        if estimate != nil {
          Button {
            commit(nil)
          } label: {
            Image(systemName: "xmark.circle.fill")
          }
          .buttonStyle(.borderless)
          .help("Clear the estimate")
          .accessibilityLabel("Clear the estimate")
        }
      }
      Slider(value: $position, in: 0...1) { editing in
        isDragging = editing
        if !editing { commit(EstimateScale.minutes(at: position)) }
      }
      .opacity(estimate == nil && !isDragging ? 0.5 : 1)
      .accessibilityLabel("Estimate")
    }
    .onAppear(perform: follow)
    .onChange(of: estimate) { follow() }
  }

  /// The estimate the slider stands at: the one being dragged to, else the one the item has.
  private var shown: Int? {
    isDragging ? EstimateScale.minutes(at: position) : estimate
  }

  private func follow() {
    guard !isDragging else { return }
    position = estimate.map(EstimateScale.position(of:)) ?? 0
  }
}
