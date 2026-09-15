import SwiftUI
import WidgetKit

/// The small widget that asks one thing: pray.
///
/// A ring with how many of today's five are done, the prayer that is next
/// with its time and the date, and a button. The count is the app's to know
/// — a prayer counts once it is confirmed with a photo of the mat — so it is
/// drawn from what the App Group was handed, and shows a dash rather than a
/// hopeful zero when the app has not synced today.
struct PrayWidgetView: View {
    let entry: NoorEntry

    private var snapshot: NoorSnapshot { entry.snapshot }
    private var shared: NoorSharedStore.State? { entry.shared }
    private var synced: Bool { !(shared?.isStale ?? true) }
    private var done: Int { synced ? (shared?.completedToday ?? 0) : 0 }
    private var total: Int { max(shared?.totalToday ?? 5, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ring
                Spacer(minLength: 4)
                LaylaBadge(size: 18)
            }

            Spacer(minLength: 4)

            Text(snapshot.next.label)
                .font(Layl.display(20))
                .foregroundStyle(Layl.cream)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 8) {
                Text(snapshot.nextDate, style: .time)
                    .font(Layl.numeral(12))
                    .foregroundStyle(Layl.mist)
                Text(entry.date, format: .dateTime.month(.twoDigits).day(.twoDigits))
                    .font(Layl.numeral(12))
                    .foregroundStyle(Layl.mistFaint)
            }
            .lineLimit(1)

            Spacer(minLength: 6)

            Link(destination: URL(string: "layla://pray")!) {
                Text("Pray")
                    .font(Layl.ui(14, weight: .semibold))
                    .foregroundStyle(Layl.midnight)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background { Capsule().fill(Layl.gold) }
            }
        }
        .widgetURL(URL(string: "layla://pray"))
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Layl.navyLine, lineWidth: 5)
            Circle()
                .trim(from: 0, to: synced ? Double(done) / Double(total) : 0)
                .stroke(
                    Layl.gold,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(synced ? "\(done)" : "–")
                    .font(Layl.numeral(16, weight: .bold))
                    .foregroundStyle(Layl.gold)
                Text("/\(total)")
                    .font(Layl.numeral(11))
                    .foregroundStyle(Layl.mist)
            }
        }
        .frame(width: 46, height: 46)
    }
}

struct PrayWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "LaylaPrayWidget",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            WidgetRoot { PrayWidgetView(entry: entry) }
        }
        .configurationDisplayName("Pray")
        .description("Today's count, the next prayer, and one button.")
        .supportedFamilies([.systemSmall])
    }
}
