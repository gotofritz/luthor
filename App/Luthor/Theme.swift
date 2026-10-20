import LuthorDomain
import SwiftUI

/// What the views draw with: the accent of the view shown and the type. Layout and colour live here and in
/// the views, never in the domain, which only names the accent.
struct Theme: Equatable {
  /// The accent as a flat fill: the rail, swatches, the capacity meter.
  let fill: Color
  /// The accent as text or an icon on the window's own background; lighter in dark mode so it stays readable.
  let ink: Color

  init(accent: ThemeAccent, isDark: Bool) {
    fill = accent.fill
    ink = isDark ? accent.lightened : accent.fill
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
  }
}

extension View {
  /// Draws this view and everything in it in `accent`.
  func themed(_ accent: ThemeAccent) -> some View {
    modifier(ThemedModifier(accent: accent))
  }
}

/// The mountain of the app icon in three tones on a clear sky: white for the lit top, a translucent white
/// for the faces in light and a dark shade for the one in shadow, so on the rail it takes on the view's accent.
struct LuthorMark: View {
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

  /// The dark shade of the face in shadow; the rail below the mark is tinted with it too.
  static let shadow = Color.black.opacity(0.3)

  /// The mountain's two sloping sides, left to right over the peak, in the icon's own coordinates.
  private static let ridge = [(850, 350), (1015, 120), (1023, 108), (1032, 120), (1180, 300)].map {
    CGPoint(x: $0.0, y: $0.1)
  }

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
        Path { path in
          for (index, point) in face.points.enumerated() {
            let scaled = CGPoint(
              x: (point.x - Self.origin.x) / Self.extent.width * geometry.size.width,
              y: (point.y - Self.origin.y) / Self.extent.height * geometry.size.height)
            if index == 0 { path.move(to: scaled) } else { path.addLine(to: scaled) }
          }
          path.closeSubpath()
        }
        .fill(face.shade.color)
      }
      Path { path in
        for (index, point) in Self.ridge.enumerated() {
          let scaled = CGPoint(
            x: (point.x - Self.origin.x) / Self.extent.width * geometry.size.width,
            y: (point.y - Self.origin.y) / Self.extent.height * geometry.size.height)
          if index == 0 { path.move(to: scaled) } else { path.addLine(to: scaled) }
        }
      }
      .stroke(Color(red: 0.2, green: 0.2, blue: 0.2), style: StrokeStyle(lineWidth: 2, lineJoin: .miter))
    }
    .aspectRatio(Self.aspectRatio, contentMode: .fit)
    .accessibilityHidden(true)
  }
}
