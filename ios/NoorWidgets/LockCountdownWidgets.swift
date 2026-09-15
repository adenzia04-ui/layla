import SwiftUI
import WidgetKit

/// Two Lock Screen tiles built around the countdown.
///
/// The Lock Screen draws these in its own vibrant material, so there is no
/// colour to work with — only weight, size and shape. Both tiles put the
/// countdown first, because that is the one thing a glance at a locked phone
/// is for, and use the rest of the tile differently: one for how far through
/// the current prayer's window the day is, one for the whole day's times.

/// "5:56" — no meridiem; the tile has no room for it and the order tells.
private let tileClock: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "h:mm"
    return f
}()

/// The live countdown to the next prayer, ticking on the Lock Screen without
/// a timeline entry per second.
private struct LockCountdown: View {
    let to: Date
    var size: CGFloat = 20

    var body: some View {
        Text(
            timerInterval: Date()...max(to, Date().addingTimeInterval(1)),
            countsDown: true
        )
        .font(.system(size: size, weight: .light, design: .rounded).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

// MARK: - Countdown with the window bar

/// Line one: the prayer's glyph, its name, the countdown. Line two: a bar
/// filling from the last prayer to the next. Line three: the Hijri date and
/// the time the prayer comes in — the two facts a person checks after the
/// countdown.
struct LockCountdownBarView: View {
    let snapshot: NoorSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: snapshot.next.symbol)
                    .font(.system(size: 13, weight: .regular))
                Text(snapshot.next.label)
                    .font(Layl.display(20, weight: .light))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                LockCountdown(to: snapshot.nextDate, size: 20)
            }
            // The window as a thin capsule: what has passed is bright, what
            // remains is faint.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.22))
                    Capsule()
                        .fill(.primary.opacity(0.9))
                        .frame(width: max(4, geo.size.width * snapshot.progress()))
                }
            }
            .frame(height: 3)
            HStack(spacing: 5) {
                Text(hijriShort)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Circle().fill(.primary.opacity(0.6)).frame(width: 3, height: 3)
                Text("at \(tileClock.string(from: snapshot.nextDate))")
                    .fixedSize()
            }
            .font(.system(size: 10.5, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
        }
    }

    /// "2 Rabi' II 1448": the era is understood on a tile this size.
    private var hijriShort: String {
        snapshot.hijri.replacingOccurrences(of: " AH", with: "")
    }
}

// MARK: - Countdown with the day's times

/// Line one: the prayer and the countdown. Under it, the five prayers as
/// five columns — glyph, three letters, time — with the next one drawn heavy
/// and a small dot beneath it, so the eye lands there without a badge.
struct LockCountdownRowView: View {
    let snapshot: NoorSnapshot

    private var obligatory: [NoorPrayer] {
        snapshot.prayers.filter { $0.key != "sunrise" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(snapshot.next.label)
                    .font(Layl.display(19, weight: .light))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                LockCountdown(to: snapshot.nextDate, size: 19)
                Spacer(minLength: 0)
            }
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(obligatory.enumerated()), id: \.element.id) { i, p in
                    if i > 0 {
                        Rectangle()
                            .fill(.primary.opacity(0.16))
                            .frame(width: 0.5)
                            .padding(.vertical, 4)
                    }
                    column(p)
                }
            }
        }
    }

    private func column(_ p: NoorPrayer) -> some View {
        let isNext = p.key == snapshot.nextKey
        return VStack(spacing: 1) {
            // Every glyph in the same 12-point box: the symbols differ in
            // height, and without this the columns sat at different levels.
            Image(systemName: p.symbol)
                .font(.system(size: 10, weight: .regular))
                .frame(height: 12)
            Text(short(p.key))
                .font(Layl.display(9, weight: isNext ? .regular : .light))
                .tracking(0.6)
                .frame(height: 11)
            Text(tileClock.string(from: p.date))
                .font(.system(size: 12.5, weight: isNext ? .medium : .light, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 14)
            Circle()
                .fill(.primary)
                .frame(width: 3, height: 3)
                .opacity(isNext ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(isNext ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
    }

    private func short(_ key: String) -> String {
        switch key {
        case "fajr": return "FJR"
        case "dhuhr": return "DHR"
        case "asr": return "ASR"
        case "maghrib": return "MGB"
        case "isha": return "ISH"
        default: return key.prefix(3).uppercased()
        }
    }
}

// MARK: - The widgets

struct LockCountdownBarWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "NoorLockCountdownBar",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            WidgetRoot { LockCountdownBarView(snapshot: entry.snapshot) }
        }
        .configurationDisplayName("Countdown & Window")
        .description("The next prayer, a live countdown, and how far the current window has run.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct LockCountdownRowWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "NoorLockCountdownRow",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            WidgetRoot { LockCountdownRowView(snapshot: entry.snapshot) }
        }
        .configurationDisplayName("Countdown & Times")
        .description("A live countdown to the next prayer with all five times in a row.")
        .supportedFamilies([.accessoryRectangular])
    }
}
