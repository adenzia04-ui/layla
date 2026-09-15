import SwiftUI
import WidgetKit

/// The wide widget: the countdown to the next prayer over a dimmed map of
/// where you are, and the whole day along the bottom with the next one lit.
struct PrayerTimesWidgetView: View {
    let entry: NoorEntry

    @Environment(\.widgetFamily) private var family

    private var snapshot: NoorSnapshot { entry.snapshot }

    var body: some View {
        if family == .accessoryRectangular {
            LockPrayerGrid(snapshot: snapshot)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 8)
                dayStrip
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    CapsLabel(text: "Next")
                    Text(snapshot.next.label)
                        .font(Layl.display(15))
                        .foregroundStyle(Layl.goldSoft)
                        .lineLimit(1)
                }
                Countdown(to: snapshot.nextDate, size: 30)
                    .padding(.top, 1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 6) {
                    Text(snapshot.city)
                        .font(Layl.ui(12, weight: .semibold))
                        .foregroundStyle(Layl.cream)
                        .lineLimit(1)
                    LaylaBadge(size: 18)
                }
                Text(snapshot.hijri)
                    .font(Layl.ui(11))
                    .foregroundStyle(Layl.mist)
                    .lineLimit(1)
                Text("at \(snapshot.nextDate, style: .time)")
                    .font(Layl.ui(11))
                    .foregroundStyle(Layl.mistFaint)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - The day

    /// Six cells, Shurooq included, names over times. No icons: at this width
    /// a glyph per cell is one more thing to read and the names already say it.
    private var dayStrip: some View {
        HStack(spacing: 4) {
            ForEach(snapshot.prayers) { prayer in
                let isNext = prayer.key == snapshot.nextKey
                VStack(spacing: 2) {
                    Text(prayer.label)
                        .font(Layl.ui(11, weight: .semibold))
                        .foregroundStyle(isNext ? Layl.cream : Layl.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(prayer.date, style: .time)
                        .font(Layl.numeral(12))
                        .foregroundStyle(isNext ? Layl.cream : Layl.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isNext ? Layl.cream.opacity(0.14) : Layl.navy.opacity(0.35))
                        .overlay {
                            if isNext {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Layl.gold.opacity(0.6), lineWidth: 1)
                            }
                        }
                }
            }
        }
    }
}

struct PrayerTimesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "NoorPrayerTimesWidget",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            WidgetRoot {
                PrayerTimesWidgetView(entry: entry)
            } art: {
                if let map = entry.mapImage {
                    Image(uiImage: map)
                        .resizable()
                        .scaledToFill()
                        .opacity(0.5)
                        .blendMode(.luminosity)
                }
                // A warm dot where the user is.
                GeometryReader { geo in
                    Circle()
                        .fill(Layl.gold)
                        .frame(width: 7, height: 7)
                        .shadow(color: Layl.gold.opacity(0.9), radius: 7)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
                }
                LinearGradient(
                    colors: [
                        Layl.midnight.opacity(0.80),
                        Layl.midnight.opacity(0.45),
                        Layl.midnight.opacity(0.92),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .configurationDisplayName("Prayer Times")
        .description("Today's prayers and a live countdown to the next one.")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
    }
}
