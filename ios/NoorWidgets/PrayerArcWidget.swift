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
///
/// Structurally the sleep-insights gauge from the reference, restyled in Layl —
/// gold instead of green, with the two endpoints labelled by prayer rather than
/// bedtime and wake-up.
struct PrayerArcWidgetView: View {
    let entry: NoorEntry

    private var snapshot: NoorSnapshot { entry.snapshot }

    private var current: NoorPrayer? {
        snapshot.prayers.first { $0.key == snapshot.currentKey }
    }

    var body: some View {
        ZStack {
            Layl.nightSky

            HStack(spacing: 14) {
                gauge
                details
            }
            .padding(14)
        }
    }

    private var gauge: some View {
        ZStack {
            ArcShape()
                .stroke(
                    Layl.navyLine,
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )

            ArcShape(to: snapshot.progress())
                .stroke(
                    AngularGradient(
                        colors: [Layl.goldDim, Layl.gold, Layl.goldSoft],
                        center: .bottom,
                        startAngle: .degrees(180),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .shadow(color: Layl.gold.opacity(0.55), radius: 7)

            VStack(spacing: 0) {
                Spacer()
                Text(
                    timerInterval: Date()...max(
                        snapshot.nextDate,
                        Date().addingTimeInterval(1)
                    ),
                    countsDown: true
                )
                .font(Layl.numeral(19, weight: .bold))
                .foregroundStyle(Layl.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

                Text("until \(snapshot.nextPrayer?.label ?? "next")")
                    .font(Layl.ui(9))
                    .foregroundStyle(Layl.mist)
                    .lineLimit(1)
            }
            .padding(.bottom, 2)
        }
        .frame(width: 118, height: 66)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "location.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(Layl.goldDim)
                Text(snapshot.city)
                    .font(Layl.ui(11, weight: .semibold))
                    .foregroundStyle(Layl.cream)
                    .lineLimit(1)

                Spacer(minLength: 4)

                streak
            }

            endpoint(
                symbol: current?.symbol ?? "moon",
                label: current?.label ?? "Now",
                date: current?.date
            )
            endpoint(
                symbol: snapshot.nextPrayer?.symbol ?? "sun.max",
                label: snapshot.nextPrayer?.label ?? "Next",
                date: snapshot.nextDate,
                highlighted: true
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Only meaningful once the app has published through the App Group, and
    /// only worth drawing when the user actually has a run going. A stale
    /// record — Noor not opened in a day and a half — is shown dimmed rather
    /// than hidden, so a number on screen is never quietly wrong.
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
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                Capsule().fill(Layl.navyElevated.opacity(0.75))
            }
        }
    }

    private func endpoint(
        symbol: String,
        label: String,
        date: Date?,
        highlighted: Bool = false
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .foregroundStyle(highlighted ? Layl.gold : Layl.mistFaint)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(Layl.ui(10))
                    .foregroundStyle(Layl.mist)
                if let date {
                    Text(date, style: .time)
                        .font(Layl.numeral(13))
                        .foregroundStyle(highlighted ? Layl.cream : Layl.mist)
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Layl.navyElevated.opacity(highlighted ? 0.85 : 0.45))
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
                .containerBackground(for: .widget) { Layl.midnight }
        }
        .configurationDisplayName("Prayer Progress")
        .description("A curved countdown from the last prayer to the next.")
        .supportedFamilies([.systemMedium])
    }
}
