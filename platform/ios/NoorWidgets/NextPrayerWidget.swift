import SwiftUI
import WidgetKit

/// The small widget: which prayer is next, and how long you have.
///
/// This slot was meant to be the streak widget. A streak lives in Firestore
/// behind the user's login, and reaching it from a widget needs an App Group —
/// a paid-membership capability. Rather than ship a widget that shows a
/// permanent placeholder, the slot does something it genuinely can: the next
/// prayer, computed locally. The streak still appears on the Lock Screen via
/// the Live Activity, where the app passes state across directly.
struct NextPrayerWidgetView: View {
    let entry: NoorEntry

    private var snapshot: NoorSnapshot { entry.snapshot }

    var body: some View {
        ZStack {
            Layl.nightSky

            MihrabShape()
                .fill(
                    LinearGradient(
                        colors: [Layl.gold.opacity(0.18), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.top, 20)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: snapshot.next.symbol)
                        .font(.system(size: 12))
                        .foregroundStyle(Layl.gold)
                    Text(snapshot.next.label)
                        .font(Layl.display(15))
                        .foregroundStyle(Layl.goldSoft)
                }

                Text(
                    timerInterval: Date()...max(
                        snapshot.nextDate,
                        Date().addingTimeInterval(1)
                    ),
                    countsDown: true
                )
                .font(Layl.numeral(27, weight: .bold))
                .foregroundStyle(Layl.cream)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.top, 2)

                Text(snapshot.nextDate, style: .time)
                    .font(Layl.numeral(13))
                    .foregroundStyle(Layl.mist)

                Spacer(minLength: 4)

                if let tahajjud = snapshot.tahajjudStart {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 9))
                            .foregroundStyle(Layl.goldDim)
                        Text("Tahajjud \(tahajjud, style: .time)")
                            .font(Layl.ui(10))
                            .foregroundStyle(Layl.mistFaint)
                            .lineLimit(1)
                    }
                }

                Text(snapshot.city)
                    .font(Layl.ui(10, weight: .semibold))
                    .foregroundStyle(Layl.mist)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
            .padding(13)
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
            NextPrayerWidgetView(entry: entry)
                .containerBackground(for: .widget) { Layl.midnight }
        }
        .configurationDisplayName("Next Prayer")
        .description("The next prayer and a live countdown.")
        .supportedFamilies([.systemSmall])
    }
}
