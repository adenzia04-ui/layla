import SwiftUI
import WidgetKit

/// The small widget: which prayer is next, and how long you have.
///
/// Also the Lock Screen: a rectangular tile with the same three facts, and an
/// inline line for above the clock.
struct NextPrayerWidgetView: View {
    let entry: NoorEntry

    @Environment(\.widgetFamily) private var family

    private var snapshot: NoorSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular
        case .accessoryCircular: LockPrayerRing(snapshot: snapshot)
        case .accessoryInline: inline
        default: small
        }
    }

    // MARK: - Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(title: "Next prayer")

            Spacer(minLength: 6)

            HStack(spacing: 6) {
                Image(systemName: snapshot.next.symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(Layl.gold)
                Text(snapshot.next.label)
                    .font(Layl.display(18))
                    .foregroundStyle(Layl.goldSoft)
                    .lineLimit(1)
            }

            Countdown(to: snapshot.nextDate, size: 30)
                .padding(.top, 1)

            Text("at \(snapshot.nextDate, style: .time)")
                .font(Layl.ui(12))
                .foregroundStyle(Layl.mist)
                .lineLimit(1)

            Spacer(minLength: 6)

            ProgressBar(fraction: snapshot.progress())
                .padding(.bottom, 6)

            PlaceLine(city: snapshot.city)
        }
    }

    // MARK: - Lock screen

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: snapshot.next.symbol)
                    .font(.system(size: 11))
                Text(snapshot.next.label)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                Spacer(minLength: 0)
                Text(snapshot.nextDate, style: .time)
                    .font(.system(size: 12, design: .rounded).monospacedDigit())
            }
            Text(
                timerInterval: Date()...max(
                    snapshot.nextDate,
                    Date().addingTimeInterval(1)
                ),
                countsDown: true
            )
            .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
    }

    private var inline: some View {
        Label {
            Text("\(snapshot.next.label) at \(snapshot.nextDate, style: .time)")
        } icon: {
            Image(systemName: snapshot.next.symbol)
        }
    }
}

struct NextPrayerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "NoorNextPrayerWidget",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            WidgetRoot { NextPrayerWidgetView(entry: entry) }
        }
        .configurationDisplayName("Next Prayer")
        .description("The next prayer and a live countdown.")
        .supportedFamilies([
            .systemSmall,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}
