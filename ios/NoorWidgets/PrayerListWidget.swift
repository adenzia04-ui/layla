import SwiftUI
import WidgetKit

/// The day as a list: a date header, how long until the next prayer, and a
/// row per prayer with the next one lit.
///
/// Medium shows the six in two columns of three; large gives each its own
/// row, with the glyphs that say what time of day it is.
struct PrayerListWidgetView: View {
    let entry: NoorEntry

    @Environment(\.widgetFamily) private var family

    private var snapshot: NoorSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .systemLarge: large
        default: medium
        }
    }

    // MARK: - Medium

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 5) {
                        CapsLabel(text: "Next")
                        Text(snapshot.next.label)
                            .font(Layl.display(14))
                            .foregroundStyle(Layl.goldSoft)
                    }
                    Countdown(to: snapshot.nextDate, size: 22)
                }
                Spacer(minLength: 6)
                dates
            }

            HStack(spacing: 10) {
                column(Array(snapshot.prayers.prefix(3)))
                column(Array(snapshot.prayers.suffix(3)))
            }
        }
    }

    private func column(_ list: [NoorPrayer]) -> some View {
        VStack(spacing: 3) {
            ForEach(list) { row($0, compact: true) }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Large

    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            dates
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(snapshot.next.label) in")
                    .font(Layl.ui(12))
                    .foregroundStyle(Layl.mist)
                Countdown(to: snapshot.nextDate, size: 34)
            }

            Spacer(minLength: 8)

            VStack(spacing: 4) {
                ForEach(snapshot.prayers) { row($0, compact: false) }
            }
        }
    }

    // MARK: - Pieces

    private var dates: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(snapshot.hijri)
                .font(Layl.ui(12, weight: .semibold))
                .foregroundStyle(Layl.cream)
                .lineLimit(1)
            Text(entry.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).year())
                .font(Layl.ui(11))
                .foregroundStyle(Layl.mist)
                .lineLimit(1)
        }
    }

    private func row(_ p: NoorPrayer, compact: Bool) -> some View {
        let isNext = p.key == snapshot.nextKey
        let past = p.date <= entry.date && !isNext
        return HStack(spacing: compact ? 6 : 10) {
            Image(systemName: p.symbol)
                .font(.system(size: compact ? 11 : 13))
                .foregroundStyle(isNext ? Layl.gold : (past ? Layl.mistFaint : p.tint.opacity(0.8)))
                .frame(width: compact ? 14 : 18)
            Text(p.label)
                .font(Layl.ui(compact ? 12 : 14, weight: .semibold))
                .foregroundStyle(isNext ? Layl.cream : (past ? Layl.mistFaint : Layl.mist))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(p.date, style: .time)
                .font(Layl.numeral(compact ? 12 : 15))
                .foregroundStyle(isNext ? Layl.cream : (past ? Layl.mistFaint : Layl.cream.opacity(0.85)))
                .lineLimit(1)
        }
        .minimumScaleFactor(0.8)
        .padding(.vertical, compact ? 4 : 7)
        .padding(.horizontal, compact ? 8 : 10)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isNext ? Layl.cream.opacity(0.12) : Layl.navy.opacity(compact ? 0.35 : 0.45))
                .overlay {
                    if isNext {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Layl.gold.opacity(0.6), lineWidth: 1)
                    }
                }
        }
    }
}

struct PrayerListWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "LaylaPrayerListWidget",
            intent: NoorWidgetConfig.self,
            provider: NoorProvider()
        ) { entry in
            WidgetRoot { PrayerListWidgetView(entry: entry) }
        }
        .configurationDisplayName("Prayer List")
        .description("The day as a list, with the next prayer lit.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
