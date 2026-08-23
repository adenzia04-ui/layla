import SwiftUI

/// The Layl palette, mirroring lib/core/theme/app_colors.dart.
///
/// **Add this file to the Runner and NoorWidgets targets.**
///
/// Kept as plain values rather than an asset catalog so the widget and the app
/// cannot drift apart silently — if a colour changes in Dart, it changes here,
/// in one obvious place.
enum Layl {
    static let midnight = Color(red: 0.024, green: 0.051, blue: 0.106)
    static let navy = Color(red: 0.043, green: 0.106, blue: 0.204)
    static let navyElevated = Color(red: 0.071, green: 0.161, blue: 0.290)
    static let navyLine = Color(red: 0.114, green: 0.227, blue: 0.388)

    static let gold = Color(red: 0.851, green: 0.698, blue: 0.416)
    static let goldSoft = Color(red: 0.941, green: 0.851, blue: 0.659)
    static let goldDim = Color(red: 0.541, green: 0.439, blue: 0.220)

    static let cream = Color(red: 0.965, green: 0.945, blue: 0.906)
    static let mist = Color(red: 0.965, green: 0.945, blue: 0.906).opacity(0.7)
    static let mistFaint =
        Color(red: 0.965, green: 0.945, blue: 0.906).opacity(0.4)

    static let emerald = Color(red: 0.180, green: 0.620, blue: 0.502)
    static let ember = Color(red: 0.941, green: 0.478, blue: 0.235)

    static let nightSky = LinearGradient(
        colors: [navy, midnight],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Playfair is bundled with the app, not the widget, so widgets use the
    /// system serif — the same *character* without shipping the font twice.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func ui(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    /// Tabular figures so countdowns do not jitter as digits change.
    static func numeral(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
            .monospacedDigit()
    }
}

/// The mihrab arch, rebuilt in SwiftUI so widgets carry the app's signature
/// shape. Matches `buildMihrabPath` in lib/core/widgets/mihrab_arch.dart.
struct MihrabShape: Shape {
    var shoulder: CGFloat = 0.42

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let springY = h * shoulder
        let cx = w / 2

        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: springY))
        path.addCurve(
            to: CGPoint(x: cx, y: 0),
            control1: CGPoint(x: 0, y: springY * 0.34),
            control2: CGPoint(x: cx - w * 0.30, y: 0)
        )
        path.addCurve(
            to: CGPoint(x: w, y: springY),
            control1: CGPoint(x: cx + w * 0.30, y: 0),
            control2: CGPoint(x: w, y: springY * 0.34)
        )
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}
