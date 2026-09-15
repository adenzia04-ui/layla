import SwiftUI
import WidgetKit

/// The five, and which of them are done.
///
/// The only widget that cannot work anything out for itself: whether someone
/// *prayed* is a fact only the app knows, once a prayer is confirmed with a
/// photo of the mat. It draws what the App Group was handed, and when it has
/// been handed nothing it says so rather than showing five hopeful empty
/// circles that look like a bad day.
struct PrayerTrackerView: View {
    let entry: NoorEntry

    private var obligatory: [NoorPrayer] {
        entry.snapshot.prayers.filter { $0.key != "sunrise" }
    }

    @Environment(\.widgetFamily) private var family

    private var shared: NoorSharedStore.State? { entry.shared }
    private var synced: Bool { !(shared?.isStale ?? true) }

    var body: some View {
        if family == .accessoryRectangular {
            LockTrackerGrid(entry: entry)
        } else {
            home
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(
                title: "Today's prayers",
                trailing: synced
                    ? "\(shared?.completedToday ?? 0) of \(shared?.totalToday ?? 5)"
                    : nil
            )
            Spacer(minLength: 8)
            track
            Spacer(minLength: 8)
            footer
        }
    }

    private var track: some View {
        HStack(spacing: 0) {
            ForEach(Array(obligatory.enumerated()), id: \.element.id) { i, p in
                let done = shared?.confirmed.contains(p.key) ?? false
                let past = p.date <= entry.date
                let isNext = p.key == entry.snapshot.nextKey

                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(done ? Layl.gold : Layl.navy.opacity(0.6))
                            .overlay {
                                Circle().stroke(
                                    done
                                        ? Layl.gold
                                        : (isNext ? Layl.gold.opacity(0.7)
                                            : (past ? Layl.mistFaint : Layl.navyLine)),
                                    lineWidth: 1.4
                                )
                            }
                            .frame(width: 30, height: 30)

                        if done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Layl.midnight)
                        } else {
                            Image(systemName: p.symbol)
                                .font(.system(size: 12))
                                .foregroundStyle(
                                    isNext ? Layl.gold : (past ? Layl.mistFaint : p.tint.opacity(0.7))
                                )
                        }
                    }

                    Text(p.label)
                        .font(Layl.ui(11, weight: .semibold))
                        .foregroundStyle(done || isNext ? Layl.cream : Layl.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)

                if i < obligatory.count - 1 {
                    // The connector is gold only where the day is done, so a
                    // run of confirmed prayers reads as one line.
                    Rectangle()
                        .fill(done ? Layl.gold.opacity(0.55) : Layl.navyLine)
                        .frame(height: 1.4)
                        .frame(maxWidth: 18)
                        .offset(y: -11)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if synced, let shared {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Layl.ember)
                Text(shared.streak == 1 ? "1 day streak" : "\(shared.streak) day streak")
                    .font(Layl.ui(11))
                    .foregroundStyle(Layl.mist)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
                    .foregroundStyle(Layl.mistFaint)
                Text("Open Layla Pro to sync today")
                    .font(Layl.ui(11))
                    .foregroundStyle(Layl.mistFaint)
            }

            Spacer(minLength: 4)

            Text("Next · \(entry.snapshot.next.label) \(entry.snapshot.nextDate, style: .time)")
                .font(Layl.ui(11))
                .foregroundStyle(Layl.mistFaint)
                .lineLimit(1)
        }
    }
}

struct PrayerTrackerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "LaylaPrayerTrackerWidget",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            WidgetRoot { PrayerTrackerView(entry: entry) }
        }
        .configurationDisplayName("Prayer Tracker")
        .description("Which of today's five you have confirmed.")
        .supportedFamilies([.systemMedium, .accessoryRectangular])
    }
}
