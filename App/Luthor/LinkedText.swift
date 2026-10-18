import AppKit
import LuthorViewModels
import SwiftUI

/// A note as a bullet and selectable text with its web addresses made links. It is a text view of AppKit, which shows the
/// pointing hand over a link and the I-beam over the rest, as SwiftUI's `Text` does not when it is selectable.
struct LinkedText: NSViewRepresentable {
  let text: String

  func makeNSView(context: Context) -> NSTextView {
    let view = NSTextView(usingTextLayoutManager: false)
    view.isEditable = false
    view.isSelectable = true
    view.drawsBackground = false
    view.textContainerInset = .zero
    view.textContainer?.lineFragmentPadding = 0
    view.textContainer?.widthTracksTextView = false
    view.isHorizontallyResizable = false
    view.isVerticallyResizable = false
    view.textStorage?.setAttributedString(attributedText)
    return view
  }

  func updateNSView(_ view: NSTextView, context: Context) {
    view.textStorage?.setAttributedString(attributedText)
  }

  /// The text as wide as `proposal` and as high as it needs, wrapping at the width.
  func sizeThatFits(_ proposal: ProposedViewSize, nsView view: NSTextView, context: Context) -> CGSize? {
    guard let container = view.textContainer, let layout = view.layoutManager else { return nil }
    let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? 280
    container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
    layout.ensureLayout(for: container)
    return CGSize(width: width, height: ceil(layout.usedRect(for: container).height))
  }

  /// A bullet, then the text hanging from it: the lines after the first start where the first starts after the bullet.
  private static let bullet = "•\t"
  private static let indent: CGFloat = 14

  private var attributedText: NSAttributedString {
    let style = NSMutableParagraphStyle()
    style.tabStops = [NSTextTab(textAlignment: .left, location: Self.indent)]
    style.defaultTabInterval = Self.indent
    style.headIndent = Self.indent
    let attributed = NSMutableAttributedString(
      string: Self.bullet + text,
      attributes: [
        .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
        .foregroundColor: NSColor.labelColor,
        .paragraphStyle: style,
      ])
    let offset = (Self.bullet as NSString).length
    for link in NoteLinks.links(in: text) {
      let range = NSRange(link.range, in: text)
      let shifted = NSRange(location: range.location + offset, length: range.length)
      attributed.addAttribute(.link, value: link.url, range: shifted)
    }
    return attributed
  }
}
