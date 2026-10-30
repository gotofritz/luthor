import AppKit
import SwiftUI

/// The strip over the boundary between two cells of a list header. It is a view of AppKit, which sets the
/// resize pointer over it and gets the mouse itself, as the cells' sort buttons around it would otherwise take
/// the hover and the clicks. A drag reports how far the mouse has moved since it began, a double click asks to fit.
struct ColumnResizeHandle: NSViewRepresentable {
  /// The mouse went down to start a drag.
  var onBegin: () -> Void
  /// How far to the right of where the drag began the mouse is, in points.
  var onDrag: (CGFloat) -> Void
  var onDoubleClick: () -> Void

  func makeNSView(context: Context) -> HandleView {
    let view = HandleView()
    update(view)
    return view
  }

  func updateNSView(_ view: HandleView, context: Context) {
    update(view)
  }

  private func update(_ view: HandleView) {
    view.onBegin = onBegin
    view.onDrag = onDrag
    view.onDoubleClick = onDoubleClick
  }

  final class HandleView: NSView {
    var onBegin: () -> Void = {}
    var onDrag: (CGFloat) -> Void = { _ in }
    var onDoubleClick: () -> Void = {}
    private var dragStartX: CGFloat = 0

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
      addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func setFrameSize(_ newSize: NSSize) {
      super.setFrameSize(newSize)
      window?.invalidateCursorRects(for: self)
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      window?.invalidateCursorRects(for: self)
    }

    override func mouseDown(with event: NSEvent) {
      if event.clickCount >= 2 {
        onDoubleClick()
      } else {
        dragStartX = event.locationInWindow.x
        onBegin()
      }
    }

    override func mouseDragged(with event: NSEvent) {
      onDrag(event.locationInWindow.x - dragStartX)
    }
  }
}
