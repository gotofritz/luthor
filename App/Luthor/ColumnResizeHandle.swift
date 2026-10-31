import AppKit
import SwiftUI

/// The grip at the foot of a column's edge, like the one Finder has. It is a view of AppKit, which sets the resize
/// pointer over it and gets the mouse itself. A drag reports how far the mouse has moved since it began, a double
/// click asks to fit.
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
    /// Whether the mouse is over the grip, which is then in the accent colour.
    private var isHovered = false {
      didSet { needsDisplay = true }
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
      addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    /// Cursor rects do not always reach a view hosted in SwiftUI, so a tracking area sets the pointer too.
    override func updateTrackingAreas() {
      super.updateTrackingAreas()
      trackingAreas.forEach(removeTrackingArea)
      addTrackingArea(
        NSTrackingArea(
          rect: .zero, options: [.cursorUpdate, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
          owner: self, userInfo: nil))
    }

    override func cursorUpdate(with event: NSEvent) {
      NSCursor.resizeLeftRight.set()
    }

    override func mouseEntered(with event: NSEvent) {
      isHovered = true
      NSCursor.resizeLeftRight.set()
    }

    override func mouseExited(with event: NSEvent) {
      isHovered = false
    }

    override func draw(_ dirtyRect: NSRect) {
      (isHovered ? NSColor.controlAccentColor : NSColor.tertiaryLabelColor).setFill()
      // Two short lines side by side, as on Finder's grip.
      for left in [bounds.midX - 2, bounds.midX + 1] {
        NSRect(x: left, y: bounds.midY - 5, width: 1, height: 10).fill()
      }
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
