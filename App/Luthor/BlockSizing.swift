import SwiftUI

/// How tall the block of a stretch of `minutes` is: its share of the grid, but never so short that its line of text
/// does not fit. The shortest blocks use a smaller font and no padding (see `compactBlock`), so they stay within
/// their place rather than overlap the next.
func blockHeight(minutes: Int, hourHeight: CGFloat) -> CGFloat {
  max(CGFloat(minutes) * hourHeight / 60 - 2, 14)
}

extension View {
  /// Fits a block's one line into a short block: a smaller font, and no padding above and below.
  func compactBlock(_ height: CGFloat) -> some View {
    font(height < 24 ? .caption2 : .body)
      .padding(.vertical, height < 24 ? 0 : 3)
  }
}
