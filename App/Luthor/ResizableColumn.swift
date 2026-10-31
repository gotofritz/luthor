import AppKit
import LuthorViewModels
import SwiftUI

/// A column of the browser that can be resized, as in Finder: a grip at the foot of its right edge is dragged to make
/// the column wider or narrower, and double-clicked to fit the column to its widest title (or, with nothing to fit,
/// to give it its usual width back). Each column keeps its width; see `LibraryViewModel.setColumnWidth`.
struct ResizableColumn: ViewModifier {
  let library: LibraryViewModel
  /// What the width is kept under.
  let id: String
  /// The width until the column is resized.
  let usually: Double
  /// The width that shows the content whole, if the column has titles to fit.
  let fit: (() -> Double?)?
  @State private var widthWhenDragBegan: Double?

  func body(content: Content) -> some View {
    content
      .frame(width: library.columnWidth(of: id, usually: usually))
      .overlay(alignment: .bottomTrailing) {
        ColumnResizeHandle(
          onBegin: { widthWhenDragBegan = library.columnWidth(of: id, usually: usually) },
          onDrag: { moved in
            library.setColumnWidth((widthWhenDragBegan ?? usually) + moved, of: id)
          },
          onDoubleClick: {
            if let width = fit?() { library.setColumnWidth(width, of: id) } else { library.resetColumnWidth(of: id) }
          }
        )
        .frame(width: 12, height: 20)
        .padding(.bottom, 4)
        .help("Drag to resize, double-click to fit")
      }
  }
}

extension View {
  /// Makes the column resizable; `fit` gives the width that shows its content whole.
  func resizableColumn(
    _ library: LibraryViewModel, id: String, usually: Double, fit: (() -> Double?)? = nil
  ) -> some View {
    modifier(ResizableColumn(library: library, id: id, usually: usually, fit: fit))
  }
}

/// How wide a title is when a row shows it.
func titleWidth(_ title: String) -> Double {
  let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
  return Double(title.size(withAttributes: [.font: font]).width.rounded(.up))
}
