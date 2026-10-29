import AppKit
import LuthorDomain
import SwiftUI

/// What the views draw with: the accent of the view shown and the type. Layout and colour live here and in
/// the views, never in the domain, which only names the accent.
struct Theme: Equatable {
  /// The accent as a flat fill: the rail, swatches, the capacity meter.
  let fill: Color
  /// The accent as text or an icon on the window's own background; lighter in dark mode so it stays readable.
  let ink: Color
  /// The accent as the body of a task block on the day grid: much lighter in dark mode, darker in light mode.
  let block: Color

  init(accent: ThemeAccent, isDark: Bool) {
    fill = accent.fill
    ink = isDark ? accent.lightened : accent.fill
    block = isDark ? accent.lightened : accent.fill
  }

  /// Section and column titles: bold, a little tight, as in a Swiss grotesque.
  static let section = Font.system(size: 15, weight: .bold)
  /// The big title of the place shown, in the header.
  static let display = Font.system(size: 30, weight: .heavy)
  /// Small, spaced, upper-case labels such as the view's name.
  static let label = Font.system(size: 11, weight: .semibold)
}

/// Red, green and blue, each between 0 and 1.
private struct RGB {
  let red: Double
  let green: Double
  let blue: Double
}

extension ThemeAccent {
  var title: String {
    switch self {
    case .navy: "Navy"
    case .alpine: "Alpine"
    case .glacier: "Glacier"
    case .forest: "Forest"
    case .plum: "Plum"
    case .graphite: "Graphite"
    case .red: "Red"
    case .sunflower: "Sunflower"
    }
  }

  /// The accent's colour as red, green and blue between 0 and 1.
  private var rgb: RGB {
    switch self {
    case .navy: RGB(red: 0.090, green: 0.247, blue: 0.471)
    case .alpine: RGB(red: 0.149, green: 0.459, blue: 0.780)
    case .glacier: RGB(red: 0.059, green: 0.545, blue: 0.553)
    case .forest: RGB(red: 0.184, green: 0.420, blue: 0.247)
    case .plum: RGB(red: 0.478, green: 0.243, blue: 0.494)
    case .graphite: RGB(red: 0.227, green: 0.251, blue: 0.282)
    case .red: RGB(red: 0.757, green: 0.173, blue: 0.173)
    case .sunflower: RGB(red: 0.851, green: 0.545, blue: 0.063)
    }
  }

  var fill: Color {
    Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
  }

  /// Half way to white: the accent as text on a dark background.
  var lightened: Color {
    Color(red: (rgb.red + 1) / 2, green: (rgb.green + 1) / 2, blue: (rgb.blue + 1) / 2)
  }
}

private struct ThemeKey: EnvironmentKey {
  static let defaultValue = Theme(accent: .navy, isDark: false)
}

extension EnvironmentValues {
  var theme: Theme {
    get { self[ThemeKey.self] }
    set { self[ThemeKey.self] = newValue }
  }
}

/// Puts the accent of the view shown into the environment, for the light or dark appearance in use.
private struct ThemedModifier: ViewModifier {
  let accent: ThemeAccent
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    let theme = Theme(accent: accent, isDark: colorScheme == .dark)
    content
      .environment(\.theme, theme)
      .tint(theme.ink)
      .accentColor(theme.ink)
  }
}

/// Fills the row of a list the view's accent while it is picked, so a pick always has the colour of the view
/// and never the system's, which changes with the window's focus.
private struct SelectionBackgroundModifier: ViewModifier {
  let isSelected: Bool
  @Environment(\.theme) private var theme
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    // The accent as ink is the lighter one in dark mode, and it needs more of it to show on a dark window.
    let fill = colorScheme == .dark ? theme.ink.opacity(0.55) : theme.fill.opacity(0.28)
    return content.listRowBackground(isSelected ? fill : Color.clear)
  }
}

/// Switches off the highlight macOS draws for the picked rows of the list it sits behind. That highlight is the
/// system's accent colour while the list has the focus and grey when it has not, so it alternates with the
/// view's own; with it off, `selectionBackground` is the only one.
private struct NoSystemHighlight: NSViewRepresentable {
  func makeNSView(context: Context) -> NSView { NSView() }

  func updateNSView(_ view: NSView, context: Context) {
    // The list is a sibling of this view, so look in the ancestors, once it is in the window, for the table
    // under this view. Columns side by side can share an ancestor, so only a table that covers this view counts.
    DispatchQueue.main.async {
      let here = view.convert(view.bounds, to: nil)
      var ancestor = view.superview
      while let current = ancestor {
        let covering = Self.tables(in: current).filter { $0.convert($0.bounds, to: nil).intersects(here) }
        if !covering.isEmpty {
          for table in covering { table.selectionHighlightStyle = .none }
          return
        }
        ancestor = current.superview
      }
    }
  }

  private static func tables(in view: NSView) -> [NSTableView] {
    if let table = view as? NSTableView { return [table] }
    return view.subviews.flatMap { tables(in: $0) }
  }
}

extension View {
  /// A list whose picked rows have only the accent of the view, from `selectionBackground`.
  func accentSelectionOnly() -> some View {
    background(NoSystemHighlight())
  }

  /// The row of a list in the accent of the view when `isSelected`.
  func selectionBackground(_ isSelected: Bool) -> some View {
    modifier(SelectionBackgroundModifier(isSelected: isSelected))
  }

  /// Draws this view and everything in it in `accent`.
  func themed(_ accent: ThemeAccent) -> some View {
    modifier(ThemedModifier(accent: accent))
  }
}

/// The mountain of the app icon in three tones on a clear sky: white for the lit top, a translucent white
/// for the faces in light and a dark shade for the one in shadow, so on the rail it takes on the view's accent.
struct LuthorMark: View {
  @Environment(\.theme) private var theme

  /// A face of the mountain, its corners in the icon's own coordinates (the peak is near 1023, 108).
  private struct Face {
    let points: [CGPoint]
    let shade: Shade

    init(_ corners: [(CGFloat, CGFloat)], _ shade: Shade) {
      points = corners.map { CGPoint(x: $0.0, y: $0.1) }
      self.shade = shade
    }
  }

  private enum Shade {
    case lit, light, shadow

    var color: Color {
      switch self {
      case .lit: Color.white
      case .light: Color.white.opacity(0.55)
      case .shadow: LuthorMark.shadow
      }
    }
  }

  /// The tint that makes the sky lighter than the rail; the masthead is on it too.
  nonisolated static let sky = Color.white.opacity(0.15)

  /// The accent with a little white, so a bit darker than the sky: the masthead rule.
  nonisolated static let edge = Color.white.opacity(0.07)

  /// The dark tint of the rail below the mark.
  nonisolated static let shadow = Color.black.opacity(0.3)

  private static let faces = [
    Face([(850, 350), (905, 315), (850, 410)], .lit),
    Face([(1015, 120), (1023, 108), (1032, 120)], .lit),
    Face([(1001, 178), (1032, 120), (1180, 300), (1115, 264), (1050, 230)], .lit),
    Face([(850, 350), (1015, 120), (1032, 120), (1001, 178), (905, 315)], .light),
    Face(
      [(1050, 230), (1115, 264), (1180, 300), (1180, 410), (1098, 410), (1010, 286)], .light),
    Face(
      [(905, 315), (1001, 178), (1050, 230), (1010, 286), (1098, 410), (850, 410)], .shadow),
  ]
  private static let origin = CGPoint(x: 850, y: 108)
  private static let extent = CGSize(width: 330, height: 302)

  /// The width over the height the mountain is drawn in.
  static let aspectRatio = extent.width / extent.height

  var body: some View {
    GeometryReader { geometry in
      ForEach(Array(Self.faces.enumerated()), id: \.offset) { _, face in
        let outline = Path { path in
          for (index, point) in face.points.enumerated() {
            let scaled = CGPoint(
              x: (point.x - Self.origin.x) / Self.extent.width * geometry.size.width,
              y: (point.y - Self.origin.y) / Self.extent.height * geometry.size.height)
            if index == 0 { path.move(to: scaled) } else { path.addLine(to: scaled) }
          }
          path.closeSubpath()
        }
        // The dark face continues the rail, so it is laid on the rail's colour, not on the lighter sky.
        if case .shadow = face.shade { outline.fill(theme.fill) }
        outline.fill(face.shade.color)
      }
    }
    .aspectRatio(Self.aspectRatio, contentMode: .fit)
    .accessibilityHidden(true)
  }
}
