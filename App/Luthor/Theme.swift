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

/// The mountain of the logo, in its simplest shape: a peak with a lit face, so the app is recognisable at
/// a glance among other windows.
struct LuthorMark: View {
  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      ZStack {
        Path { path in
          path.move(to: CGPoint(x: 0, y: size.height))
          path.addLine(to: CGPoint(x: size.width * 0.46, y: 0))
          path.addLine(to: CGPoint(x: size.width, y: size.height))
          path.closeSubpath()
        }
        .fill(.white)
        Path { path in
          path.move(to: CGPoint(x: size.width * 0.46, y: 0))
          path.addLine(to: CGPoint(x: size.width, y: size.height))
          path.addLine(to: CGPoint(x: size.width * 0.52, y: size.height))
          path.closeSubpath()
        }
        .fill(Color.white.opacity(0.45))
      }
    }
    .accessibilityHidden(true)
  }
}
