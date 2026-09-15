import SwiftUI
import WidgetKit

/// One colour set for the widgets. Mirrors `WidgetTheme` in Dart
/// (lib/features/widgets/domain/widget_theme.dart); the ids must match.
struct LaylPalette {
    let midnight: Color      // the darkest ground
    let navy: Color          // the default surface
    let navyElevated: Color  // cards on the surface
    let navyLine: Color      // hairlines
    let gold: Color          // the accent
    let goldSoft: Color
    let goldDim: Color
    let cream: Color         // body text

    static let midnight = LaylPalette(
        midnight: Color(red: 0.031, green: 0.071, blue: 0.157),
        navy: Color(red: 0.086, green: 0.188, blue: 0.369),
        navyElevated: Color(red: 0.178, green: 0.269, blue: 0.432),
        navyLine: Color(red: 0.306, green: 0.383, blue: 0.520),
        gold: Color(red: 0.886, green: 0.725, blue: 0.416),
        goldSoft: Color(red: 0.953, green: 0.867, blue: 0.659),
        goldDim: Color(red: 0.576, green: 0.472, blue: 0.270),
        cream: Color(red: 0.965, green: 0.945, blue: 0.906)
    )

    static func named(_ id: String) -> LaylPalette {
        switch id {
        case "emerald":
            return LaylPalette(
                midnight: Color(red: 0.020, green: 0.180, blue: 0.141),
                navy: Color(red: 0.059, green: 0.420, blue: 0.322),
                navyElevated: Color(red: 0.153, green: 0.478, blue: 0.389),
                navyLine: Color(red: 0.285, green: 0.559, blue: 0.484),
                gold: Color(red: 0.549, green: 0.941, blue: 0.769),
                goldSoft: Color(red: 0.784, green: 0.969, blue: 0.886),
                goldDim: Color(red: 0.357, green: 0.612, blue: 0.500),
                cream: Color(red: 0.937, green: 0.980, blue: 0.957)
            )
        case "rose":
            return LaylPalette(
                midnight: Color(red: 0.227, green: 0.047, blue: 0.165),
                navy: Color(red: 0.478, green: 0.122, blue: 0.345),
                navyElevated: Color(red: 0.531, green: 0.209, blue: 0.411),
                navyLine: Color(red: 0.604, green: 0.332, blue: 0.502),
                gold: Color(red: 1.000, green: 0.612, blue: 0.776),
                goldSoft: Color(red: 1.000, green: 0.816, blue: 0.890),
                goldDim: Color(red: 0.650, green: 0.398, blue: 0.505),
                cream: Color(red: 1.000, green: 0.941, blue: 0.965)
            )
        case "ember":
            return LaylPalette(
                midnight: Color(red: 0.239, green: 0.086, blue: 0.039),
                navy: Color(red: 0.541, green: 0.227, blue: 0.118),
                navyElevated: Color(red: 0.587, green: 0.305, blue: 0.206),
                navyLine: Color(red: 0.651, green: 0.413, blue: 0.329),
                gold: Color(red: 1.000, green: 0.702, blue: 0.478),
                goldSoft: Color(red: 1.000, green: 0.851, blue: 0.737),
                goldDim: Color(red: 0.650, green: 0.456, blue: 0.311),
                cream: Color(red: 1.000, green: 0.953, blue: 0.918)
            )
        case "violet":
            return LaylPalette(
                midnight: Color(red: 0.114, green: 0.071, blue: 0.298),
                navy: Color(red: 0.271, green: 0.188, blue: 0.612),
                navyElevated: Color(red: 0.344, green: 0.269, blue: 0.651),
                navyLine: Color(red: 0.446, green: 0.383, blue: 0.705),
                gold: Color(red: 0.788, green: 0.706, blue: 1.000),
                goldSoft: Color(red: 0.894, green: 0.847, blue: 1.000),
                goldDim: Color(red: 0.512, green: 0.459, blue: 0.650),
                cream: Color(red: 0.961, green: 0.945, blue: 1.000)
            )
        case "ocean":
            return LaylPalette(
                midnight: Color(red: 0.020, green: 0.165, blue: 0.227),
                navy: Color(red: 0.055, green: 0.361, blue: 0.471),
                navyElevated: Color(red: 0.149, green: 0.425, blue: 0.524),
                navyLine: Color(red: 0.282, green: 0.514, blue: 0.598),
                gold: Color(red: 0.498, green: 0.890, blue: 1.000),
                goldSoft: Color(red: 0.769, green: 0.945, blue: 1.000),
                goldDim: Color(red: 0.324, green: 0.579, blue: 0.650),
                cream: Color(red: 0.933, green: 0.976, blue: 0.992)
            )
        case "sapphire":
            return LaylPalette(
                midnight: Color(red: 0.043, green: 0.122, blue: 0.333),
                navy: Color(red: 0.118, green: 0.310, blue: 0.722),
                navyElevated: Color(red: 0.206, green: 0.379, blue: 0.749),
                navyLine: Color(red: 0.329, green: 0.475, blue: 0.788),
                gold: Color(red: 0.663, green: 0.784, blue: 1.000),
                goldSoft: Color(red: 0.839, green: 0.894, blue: 1.000),
                goldDim: Color(red: 0.431, green: 0.510, blue: 0.650),
                cream: Color(red: 0.945, green: 0.961, blue: 1.000)
            )
        case "slate":
            return LaylPalette(
                midnight: Color(red: 0.063, green: 0.071, blue: 0.094),
                navy: Color(red: 0.169, green: 0.184, blue: 0.227),
                navyElevated: Color(red: 0.252, green: 0.266, blue: 0.305),
                navyLine: Color(red: 0.368, green: 0.380, blue: 0.413),
                gold: Color(red: 0.890, green: 0.902, blue: 0.933),
                goldSoft: Color(red: 0.965, green: 0.969, blue: 0.980),
                goldDim: Color(red: 0.579, green: 0.586, blue: 0.607),
                cream: Color(red: 0.965, green: 0.965, blue: 0.973)
            )
        case "sand":
            return LaylPalette(
                midnight: Color(red: 0.922, green: 0.867, blue: 0.761),
                navy: Color(red: 0.984, green: 0.953, blue: 0.890),
                navyElevated: Color(red: 0.906, green: 0.877, blue: 0.819),
                navyLine: Color(red: 0.807, green: 0.781, blue: 0.730),
                gold: Color(red: 0.549, green: 0.353, blue: 0.118),
                goldSoft: Color(red: 0.722, green: 0.541, blue: 0.271),
                goldDim: Color(red: 0.707, green: 0.579, blue: 0.426),
                cream: Color(red: 0.165, green: 0.106, blue: 0.039)
            )
        default:
            return .midnight
        }
    }
}

/// Which palette the widgets draw in right now.
///
/// Read from the App Group and cached for a couple of seconds: a render
/// touches `Layl` colours hundreds of times, and parsing the snapshot on each
/// would be wasteful, but a timeline reload after the user picks a new set
/// must see the change.
enum LaylTheme {
    nonisolated(unsafe) private static var cached = LaylPalette.midnight
    nonisolated(unsafe) private static var loadedAt = Date.distantPast

    static var current: LaylPalette {
        if Date().timeIntervalSince(loadedAt) > 2 {
            cached = LaylPalette.named(NoorSharedStore.readTheme())
            loadedAt = Date()
        }
        return cached
    }
}

/// The Layla palette, mirroring lib/core/theme/app_colors.dart — resolved
/// through the theme the user picked in Settings, so every widget follows it
/// without touching a single call site.
enum Layl {
    static var midnight: Color { LaylTheme.current.midnight }
    static var navy: Color { LaylTheme.current.navy }
    static var navyElevated: Color { LaylTheme.current.navyElevated }
    static var navyLine: Color { LaylTheme.current.navyLine }

    static var gold: Color { LaylTheme.current.gold }
    static var goldSoft: Color { LaylTheme.current.goldSoft }
    static var goldDim: Color { LaylTheme.current.goldDim }

    static var cream: Color { LaylTheme.current.cream }
    static var mist: Color { LaylTheme.current.cream.opacity(0.7) }
    static var mistFaint: Color { LaylTheme.current.cream.opacity(0.45) }

    static let emerald = Color(red: 0.180, green: 0.620, blue: 0.502)
    static let ember = Color(red: 0.941, green: 0.478, blue: 0.235)

    /// The app's one blue, reserved for presence and, here, the Live Activity.
    static let pulse = Color(red: 0.302, green: 0.651, blue: 1.0)
    static let pulseSoft = Color(red: 0.612, green: 0.824, blue: 1.0)
    static let deepNavy = Color(red: 0.043, green: 0.106, blue: 0.204)

    static var nightSky: LinearGradient {
        LinearGradient(
            colors: [navy, midnight],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Outfit, bundled with the extension too, so a widget's title is set in
    /// the same face as the app's. The weight goes through the font's own
    /// axis; SwiftUI applies it to a variable font.
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("Outfit", size: size).weight(weight)
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

// MARK: - The pieces every widget is built from

/// A small gold label in capitals, the way the app titles its sections
/// ("TODAY'S PROGRESS", "MAIN FEATURES"). One glance says what a widget is.
struct CapsLabel: View {
    let text: String
    var color: Color = Layl.gold

    var body: some View {
        Text(text.uppercased())
            .font(Layl.ui(10, weight: .semibold))
            .tracking(1.3)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// The header row: a caps label on the left, the mark on the right.
///
/// The mark is eighteen points. It used to be thirty, with the word LAYLA
/// beside it, pinned over every widget with forty-six points of padding
/// reserved beneath — a third of a medium widget given to a logo, and the
/// content squeezed into what was left. The home screen already prints the
/// app's name under every widget; the mark only has to say "this one is ours".
struct WidgetHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            CapsLabel(text: title)
            Spacer(minLength: 4)
            if let trailing {
                Text(trailing)
                    .font(Layl.numeral(11))
                    .foregroundStyle(Layl.gold)
                    .lineLimit(1)
            }
            LaylaBadge(size: 18)
        }
    }
}

/// The sky behind every widget, drawn as the container background so it
/// runs to the edge while the content keeps the system's own margins.
struct NightBackground<Art: View>: View {
    var art: () -> Art

    init(@ViewBuilder art: @escaping () -> Art) {
        self.art = art
    }

    var body: some View {
        ZStack {
            Layl.nightSky
            art()
        }
    }
}

extension NightBackground where Art == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}

extension WidgetFamily {
    /// Lock Screen and watch families, drawn by the system in its own
    /// vibrant material rather than in our colours.
    var isAccessory: Bool {
        switch self {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            return true
        default:
            return false
        }
    }
}

/// The root of every widget: the night sky behind home-screen families, the
/// system's frosted material behind Lock Screen ones. One modifier, so no
/// widget can forget the difference.
struct WidgetRoot<Content: View, Art: View>: View {
    @Environment(\.widgetFamily) private var family

    let content: Content
    let art: () -> Art

    init(@ViewBuilder content: () -> Content, @ViewBuilder art: @escaping () -> Art) {
        self.content = content()
        self.art = art
    }

    var body: some View {
        if family.isAccessory {
            content.containerBackground(for: .widget) {
                AccessoryWidgetBackground()
            }
        } else {
            content.containerBackground(for: .widget) {
                NightBackground(art: art)
            }
        }
    }
}

extension WidgetRoot where Art == EmptyView {
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content) { EmptyView() }
    }
}

/// A live countdown to a moment, ticking on its own without waking the
/// widget. Never negative: a target in the past is clamped a second ahead.
struct Countdown: View {
    let to: Date
    var size: CGFloat = 28
    var weight: Font.Weight = .bold
    var color: Color = Layl.cream

    /// A live timer reserves room for its widest possible value and sits at
    /// the left of it; a centred layout has to say so, or the digits drift
    /// left of whatever they are meant to sit under.
    var alignment: TextAlignment = .leading

    var body: some View {
        Text(
            timerInterval: Date()...max(to, Date().addingTimeInterval(1)),
            countsDown: true
        )
        .font(Layl.numeral(size, weight: weight))
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .multilineTextAlignment(alignment)
        .frame(
            maxWidth: alignment == .center ? .infinity : nil,
            alignment: alignment == .center ? .center : .leading
        )
    }
}

/// A thin gold bar, filled to `fraction`.
struct ProgressBar: View {
    let fraction: Double
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Layl.cream.opacity(0.14))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Layl.goldDim, Layl.gold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
    }
}

/// A place, with the little location glyph the app uses.
struct PlaceLine: View {
    let city: String
    var size: CGFloat = 11
    var color: Color = Layl.mist

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill")
                .font(.system(size: size - 2))
                .foregroundStyle(Layl.goldDim)
            Text(city)
                .font(Layl.ui(size, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
        }
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
