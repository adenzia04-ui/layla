import SwiftUI
import WidgetKit

/// The wide widget: a dimmed map of where you are, the live countdown to the
/// next prayer, and the whole day along the bottom with the next one lit.
///
/// The map is rendered by the *app* (see WidgetBridge.refreshMap) and written
/// to the App Group as a PNG. Widgets get a tight memory and time budget, and
/// MKMapSnapshotter inside a timeline provider is a reliable way to blow it —
/// so the widget only ever draws an image someone else prepared.
struct PrayerTimesWidgetView: View {
    let entry: NoorEntry

    private var snapshot: NoorSnapshot { entry.snapshot }

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 8)
                prayerRow
                progressBar
                    .padding(.top, 8)
            }
            .padding(14)
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Layl.nightSky

            if let map = entry.mapImage {
                Image(uiImage: map)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.5)
                    .blendMode(.luminosity)
            }

            // A warm dot where the user is — the reference's sun over the map.
            GeometryReader { geo in
                Circle()
                    .fill(Layl.gold)
                    .frame(width: 7, height: 7)
                    .shadow(color: Layl.gold.opacity(0.9), radius: 7)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
            }

            LinearGradient(
                colors: [
                    Layl.midnight.opacity(0.86),
                    Layl.midnight.opacity(0.45),
                    Layl.midnight.opacity(0.92),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.nextPrayer?.label ?? "Next")
                    .font(Layl.display(15))
                    .foregroundStyle(Layl.goldSoft)

                // Ticks on its own, no timeline reload needed.
                Text(
                    timerInterval: Date()...max(
                        snapshot.nextDate,
                        Date().addingTimeInterval(1)
                    ),
                    countsDown: true
                )
                .font(Layl.numeral(26, weight: .bold))
                .foregroundStyle(Layl.cream)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(snapshot.city)
                    .font(Layl.ui(13, weight: .semibold))
                    .foregroundStyle(Layl.cream)
                    .lineLimit(1)
                Text(snapshot.hijri)
                    .font(Layl.ui(11))
                    .foregroundStyle(Layl.mist)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - The day

    private var prayerRow: some View {
        HStack(spacing: 4) {
            ForEach(snapshot.prayers) { prayer in
                let isNext = prayer.key == snapshot.nextKey
                VStack(spacing: 3) {
                    Text(prayer.label)
                        .font(Layl.ui(10, weight: .semibold))
                        .foregroundStyle(isNext ? Layl.cream : Layl.mist)
                    Image(systemName: prayer.symbol)
                        .font(.system(size: 12))
                        .foregroundStyle(isNext ? Layl.gold : Layl.mistFaint)
                    Text(prayer.date, style: .time)
                        .font(Layl.numeral(11))
                        .foregroundStyle(isNext ? Layl.cream : Layl.mist)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background {
                    if isNext {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Layl.cream.opacity(0.14))
                            .overlay {
                                RoundedRectangle(
                                    cornerRadius: 9,
                                    style: .continuous
                                )
                                .stroke(Layl.gold.opacity(0.55), lineWidth: 1)
                            }
                    }
                }
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Layl.cream.opacity(0.16))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Layl.goldDim, Layl.gold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * snapshot.progress())
            }
        }
        .frame(height: 4)
    }
}

struct PrayerTimesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "NoorPrayerTimesWidget",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            PrayerTimesWidgetView(entry: entry)
                .containerBackground(for: .widget) { Layl.midnight }
        }
        .configurationDisplayName("Prayer Times")
        .description("Today's prayers and a live countdown to the next one.")
        .supportedFamilies([.systemMedium])
    }
}
