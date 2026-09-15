import SwiftUI
import WidgetKit

/// The large widget: the whole day laid out over the globe.
///
/// The date across the top, the countdown as the one big thing, then six cells
/// in two rows so every prayer is one glance rather than a scan, and where you
/// are along the bottom. The globe behind it is the app's own — the same
/// textured sphere from the home screen, drawn by the app and handed over
/// through the App Group — under a scrim, because it is the ground the times
/// stand on and must not compete with them.
struct GlobeWidgetView: View {
    let entry: NoorEntry

    private var snapshot: NoorSnapshot { entry.snapshot }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 10)
            hero
            Spacer(minLength: 10)
            rule
            Spacer(minLength: 10)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(snapshot.prayers) { cell(for: $0) }
            }
            Spacer(minLength: 10)
            footer
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                CapsLabel(text: "Today")
                Text(snapshot.hijri)
                    .font(Layl.ui(13, weight: .medium))
                    .foregroundStyle(Layl.cream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(Layl.ui(12))
                    .foregroundStyle(Layl.mist)
                    .lineLimit(1)
                PlaceLine(city: snapshot.city, size: 11, color: Layl.cream)
            }
        }
    }

    /// The one big thing: how long until the next prayer.
    private var hero: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Until \(snapshot.next.label)")
                    .font(Layl.ui(12))
                    .foregroundStyle(Layl.mist)
                Countdown(to: snapshot.nextDate, size: 38)
            }
            Spacer(minLength: 4)
            HStack(spacing: 7) {
                Image(systemName: snapshot.next.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(Layl.gold)
                VStack(alignment: .leading, spacing: 0) {
                    Text(snapshot.next.label)
                        .font(Layl.display(15))
                        .foregroundStyle(Layl.goldSoft)
                    Text(snapshot.nextDate, style: .time)
                        .font(Layl.numeral(13))
                        .foregroundStyle(Layl.cream)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Layl.navyElevated.opacity(0.85))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Layl.gold.opacity(0.45), lineWidth: 1)
                    }
            }
        }
    }

    private var rule: some View {
        Rectangle()
            .fill(Layl.cream.opacity(0.14))
            .frame(height: 0.7)
    }

    private func cell(for p: NoorPrayer) -> some View {
        let isNext = p.key == snapshot.nextKey
        let past = p.date <= entry.date && !isNext
        return VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: p.symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(isNext ? Layl.gold : (past ? Layl.mistFaint : p.tint.opacity(0.8)))
                Text(p.label)
                    .font(Layl.ui(13, weight: .semibold))
                    .foregroundStyle(isNext ? Layl.cream : (past ? Layl.mistFaint : Layl.mist))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(p.date, style: .time)
                .font(Layl.numeral(16))
                .foregroundStyle(isNext ? Layl.cream : (past ? Layl.mistFaint : Layl.cream.opacity(0.85)))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        // No box behind a time: the next prayer is told apart by its gold
        // glyph and brighter figures, nothing else.
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if let tahajjud = snapshot.tahajjudStart {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Layl.goldDim)
                Text("Tahajjud from \(tahajjud, style: .time)")
                    .font(Layl.ui(11))
                    .foregroundStyle(Layl.mist)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            LaylaBadge(size: 18)
        }
    }
}

struct GlobeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "LaylaGlobeWidget",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            GlobeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    NightBackground {
                        if let globe = entry.globeImage {
                            Image(uiImage: globe)
                                .resizable()
                                .scaledToFill()
                                .opacity(0.42)
                        }
                        // Legibility first: six times and a running countdown
                        // over a sphere need a scrim, lifted a little at the
                        // top where the globe is worth seeing.
                        LinearGradient(
                            colors: [
                                Layl.midnight.opacity(0.60),
                                Layl.midnight.opacity(0.86),
                                Layl.midnight.opacity(0.94),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
        }
        .configurationDisplayName("Globe & Prayer Times")
        .description("The whole day, over the globe from your home screen.")
        .supportedFamilies([.systemLarge])
    }
}
