import SwiftUI
import WidgetKit

// MARK: - Duas

/// The dua library, one tap from the home screen.
///
/// Three ways in rather than one: "all of them" is the least useful door when
/// what someone actually wants at 6am is the morning adhkar.
struct DuasView: View {
    let entry: NoorEntry

    private struct Door: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let url: String
    }

    private let doors: [Door] = [
        Door(id: "morning", title: "Morning &\nEvening",
             symbol: "sun.horizon.fill", url: "layla://duas/morning"),
        Door(id: "praise", title: "Praising\nAllah",
             symbol: "sparkles", url: "layla://duas/praise"),
        Door(id: "all", title: "All\nDuas",
             symbol: "book.closed.fill", url: "layla://duas"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(title: "Duas")

            HStack(spacing: 8) {
                ForEach(doors) { door in
                    Link(destination: URL(string: door.url)!) {
                        VStack(spacing: 8) {
                            Image(systemName: door.symbol)
                                .font(.system(size: 20))
                                .foregroundStyle(Layl.gold)
                            Text(door.title)
                                .font(Layl.ui(12, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Layl.cream)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Layl.navyElevated.opacity(0.9))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Layl.navyLine, lineWidth: 1)
                                }
                        }
                    }
                }
            }
        }
    }
}

struct DuasWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "LaylaDuasWidget",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            DuasView(entry: entry)
                .containerBackground(for: .widget) { NightBackground() }
        }
        .configurationDisplayName("Duas")
        .description("Morning and evening adhkar, praise, and the full library.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Qibla

/// The bearing to the Kaaba.
///
/// Deliberately not a live compass: a widget has no magnetometer and is
/// redrawn on a timeline, so a needle here would quietly lie about which way
/// you are facing. The bearing from north does not change while you stand
/// still, and that is what it shows. Tapping opens the real compass.
struct QiblaWidgetView: View {
    let entry: NoorEntry

    private var bearing: Double { entry.snapshot.qiblaBearing }

    var body: some View {
        VStack(spacing: 0) {
            WidgetHeader(title: "Qibla")

            Spacer(minLength: 4)

            ZStack {
                Circle()
                    .stroke(Layl.navyLine, lineWidth: 1.2)
                // Four ticks, north lit, so the bearing has something to be
                // relative to.
                ForEach(0..<4, id: \.self) { i in
                    Capsule()
                        .fill(i == 0 ? Layl.gold : Layl.navyLine)
                        .frame(width: 2, height: i == 0 ? 8 : 5)
                        .offset(y: -38)
                        .rotationEffect(.degrees(Double(i) * 90))
                }
                Image(systemName: "location.north.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Layl.gold)
                    .shadow(color: Layl.gold.opacity(0.6), radius: 6)
                    .rotationEffect(.degrees(bearing))
            }
            .frame(width: 84, height: 84)

            Spacer(minLength: 4)

            Text("\(Int(bearing.rounded()))° from north")
                .font(Layl.numeral(13))
                .foregroundStyle(Layl.cream)
                .lineLimit(1)
            Text("Tap to align")
                .font(Layl.ui(11))
                .foregroundStyle(Layl.mistFaint)
        }
        .widgetURL(URL(string: "layla://qibla"))
    }
}

struct QiblaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "LaylaQiblaWidget",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            QiblaWidgetView(entry: entry)
                .containerBackground(for: .widget) { NightBackground() }
        }
        .configurationDisplayName("Qibla")
        .description("The bearing to the Kaaba from where you are.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Tasbih

/// Today's dhikr count.
struct TasbihWidgetView: View {
    let entry: NoorEntry

    private var count: Int { entry.shared?.tasbihToday ?? 0 }
    private var known: Bool { !(entry.shared?.isStale ?? true) }

    var body: some View {
        VStack(spacing: 0) {
            WidgetHeader(title: "Tasbih")

            Spacer(minLength: 4)

            Text(known ? "\(count)" : "—")
                .font(Layl.numeral(44, weight: .bold))
                .foregroundStyle(Layl.cream)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(known ? "dhikr today" : "Open Layla Pro to sync")
                .font(Layl.ui(12))
                .foregroundStyle(Layl.mist)
                .lineLimit(1)

            Spacer(minLength: 4)

            HStack(spacing: 5) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Layl.goldDim)
                Text("Tap to count")
                    .font(Layl.ui(11))
                    .foregroundStyle(Layl.mistFaint)
            }
        }
        .widgetURL(URL(string: "layla://tasbih"))
    }
}

struct TasbihWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "LaylaTasbihWidget",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            TasbihWidgetView(entry: entry)
                .containerBackground(for: .widget) { NightBackground() }
        }
        .configurationDisplayName("Tasbih")
        .description("Your dhikr count for today.")
        .supportedFamilies([.systemSmall])
    }
}
