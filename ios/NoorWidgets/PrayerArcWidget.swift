import SwiftUI
import WidgetKit

/// A semicircular gauge, opening downward like a rainbow. `trim` fills it from
/// the left endpoint.
struct ArcShape: Shape {
    var from: Double = 0
    var to: Double = 1

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width / 2, rect.height)
        let centre = CGPoint(x: rect.midX, y: rect.maxY)
        var path = Path()
        path.addArc(
            center: centre,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        return path.trimmedPath(from: from, to: to)
    }
}

/// The curved-gauge widget: how far through the current stretch of the day you
/// are, from the prayer that just passed to the one coming.
struct PrayerArcWidgetView: View {
    let entry: NoorEntry

    private var snapshot: NoorSnapshot { entry.snapshot }

    private var current: NoorPrayer? {
        snapshot.prayers.first { $0.key == snapshot.currentKey }
    }

    var body: some View {
        HStack(spacing: 16) {
            readout
            details
        }
    }

    /// The arc, with a sun travelling along it.
    ///
    /// The stroke used to start at the left end however little of the day
    /// had passed, and ten minutes into a six-hour stretch it was a fat gold
    /// blob on the end of the track — true, and it looked broken. Now a
    /// glowing marker sits where you are on the arc, and the gold stroke only
    /// appears behind it once there is enough of it to read as a line.
    private var gauge: some View {
        let progress = snapshot.progress()
        return ZStack {
            ArcShape()
                .stroke(
                    Layl.navyLine,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )

            if progress > 0.06 {
                ArcShape(to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [Layl.goldDim, Layl.gold, Layl.goldSoft],
                            center: .bottom,
                            startAngle: .degrees(180),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .shadow(color: Layl.gold.opacity(0.45), radius: 5)
            }

            GeometryReader { geo in
                let radius = min(geo.size.width / 2, geo.size.height)
                let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height)
                let angle = Double.pi * (1 - progress)
                Circle()
                    .fill(Layl.goldSoft)
                    .frame(width: 13, height: 13)
                    .shadow(color: Layl.gold.opacity(0.9), radius: 7)
                    .position(
                        x: centre.x + radius * cos(angle),
                        y: centre.y - radius * sin(angle)
                    )
            }
        }
        .frame(width: 124, height: 62)
    }

    /// The arc, and the number under it — not inside it, where a wide value
    /// like "4:04:54" ran into the gold.
    private var readout: some View {
        VStack(spacing: 6) {
            gauge
            Countdown(to: snapshot.nextDate, size: 22, alignment: .center)
            Text("until \(snapshot.next.label)")
                .font(Layl.ui(11))
                .foregroundStyle(Layl.mist)
                .lineLimit(1)
        }
        .frame(width: 132)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                PlaceLine(city: snapshot.city, size: 11, color: Layl.cream)
                Spacer(minLength: 4)
                streak
                LaylaBadge(size: 18)
            }

            // Before Fajr nothing is running; the stretch is the night.
            endpoint(
                symbol: current?.symbol ?? "moon.fill",
                label: current?.label ?? "Night",
                date: current?.date
            )
            endpoint(
                symbol: snapshot.next.symbol,
                label: snapshot.next.label,
                date: snapshot.nextDate,
                highlighted: true
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Only worth drawing when the user has a run going. A stale record —
    /// the app not opened in a day and a half — is dimmed, never hidden, so a
    /// number on screen is never quietly wrong.
    @ViewBuilder
    private var streak: some View {
        if let shared = entry.shared, shared.streak > 0 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9))
                Text("\(shared.streak)")
                    .font(Layl.numeral(11, weight: .bold))
            }
            .foregroundStyle(shared.isStale ? Layl.mistFaint : Layl.gold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background { Capsule().fill(Layl.navyElevated.opacity(0.8)) }
        }
    }

    private func endpoint(
        symbol: String,
        label: String,
        date: Date?,
        highlighted: Bool = false
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(highlighted ? Layl.gold : Layl.mistFaint)
                .frame(width: 16)

            Text(label)
                .font(Layl.ui(12, weight: .semibold))
                .foregroundStyle(highlighted ? Layl.cream : Layl.mist)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let date {
                Text(date, style: .time)
                    .font(Layl.numeral(13))
                    .foregroundStyle(highlighted ? Layl.cream : Layl.mist)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Layl.navyElevated.opacity(highlighted ? 0.9 : 0.45))
                .overlay {
                    if highlighted {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Layl.gold.opacity(0.5), lineWidth: 1)
                    }
                }
        }
    }
}

struct PrayerArcWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "NoorPrayerArcWidget",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            PrayerArcWidgetView(entry: entry)
                .containerBackground(for: .widget) { NightBackground() }
        }
        .configurationDisplayName("Prayer Progress")
        .description("A curved countdown from the last prayer to the next.")
        .supportedFamilies([.systemMedium])
    }
}
