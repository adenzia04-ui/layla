import SwiftUI
import WidgetKit

/// "5:58" — no AM or PM, no leading zero. The order of the rows says which
/// half of the day a time belongs to, and the tile has no room to say it twice.
private let lockClock: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "h:mm"
    return f
}()

private func lockTime(_ date: Date) -> String {
    lockClock.string(from: date)
}

// MARK: - The grid

/// Six times in two columns, the next one in a bright pill.
///
/// Shurooq is the sunrise glyph rather than the word: it is the one row that
/// is not a prayer, and the glyph says so at a glance while keeping the
/// columns even.
struct LockPrayerGrid: View {
    let snapshot: NoorSnapshot

    private var left: [NoorPrayer] { Array(snapshot.prayers.prefix(3)) }
    private var right: [NoorPrayer] { Array(snapshot.prayers.suffix(3)) }

    var body: some View {
        HStack(spacing: 6) {
            column(left)
            column(right)
        }
    }

    private func column(_ list: [NoorPrayer]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(list) { row($0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Times without AM or PM: the order says which is which, and the tile
    /// is 150-odd points wide for two columns of name and time.
    private func row(_ p: NoorPrayer) -> some View {
        let isNext = p.key == snapshot.nextKey
        return HStack(spacing: 3) {
            if p.key == "sunrise" {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 10))
            } else {
                Text(p.label)
                    .font(.system(size: 11, weight: isNext ? .semibold : .regular, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 2)
            // Rigid, so the name is the only thing that gives.
            Text(lockTime(p.date))
                .font(.system(size: 11, weight: isNext ? .semibold : .regular, design: .rounded).monospacedDigit())
                .fixedSize()
                .layoutPriority(1)
        }
        .padding(.horizontal, 3)
        .padding(.vertical, 1)
        .foregroundStyle(isNext ? AnyShapeStyle(.black) : AnyShapeStyle(.primary))
        .background {
            if isNext {
                Capsule().fill(.white)
            }
        }
    }
}

// MARK: - The tracker

/// The five, with a dot each: filled once confirmed, hollow until then. The
/// sixth cell carries the streak.
struct LockTrackerGrid: View {
    let entry: NoorEntry

    private var obligatory: [NoorPrayer] {
        entry.snapshot.prayers.filter { $0.key != "sunrise" }
    }

    var body: some View {
        let left = Array(obligatory.prefix(3))
        let right = Array(obligatory.suffix(2))
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(left) { row($0) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                ForEach(right) { row($0) }
                streak
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ p: NoorPrayer) -> some View {
        let done = entry.shared?.confirmed.contains(p.key) ?? false
        let isNext = p.key == entry.snapshot.nextKey
        return HStack(spacing: 2) {
            Image(systemName: done ? "circle.fill" : "circle")
                .font(.system(size: 7))
            // The dot costs the name its room, so it may shrink further here.
            Text(p.label)
                .font(.system(size: 11, weight: isNext || done ? .semibold : .regular, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Spacer(minLength: 2)
            Text(lockTime(p.date))
                .font(.system(size: 11, weight: isNext ? .semibold : .regular, design: .rounded).monospacedDigit())
                .fixedSize()
                .layoutPriority(1)
        }
        .padding(.vertical, 1)
    }

    private var streak: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 9))
            Text(
                (entry.shared?.isStale ?? true)
                    ? "Open to sync"
                    : "\(entry.shared?.streak ?? 0) day streak"
            )
            .font(.system(size: 11, design: .rounded))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.vertical, 1)
    }
}

// MARK: - The ring

/// A circular gauge that fills from the last prayer to the next, the next
/// prayer's time inside it.
struct LockPrayerRing: View {
    let snapshot: NoorSnapshot

    var body: some View {
        Gauge(value: snapshot.progress()) {
            EmptyView()
        } currentValueLabel: {
            VStack(spacing: 0) {
                Image(systemName: snapshot.next.symbol)
                    .font(.system(size: 11))
                Text(lockTime(snapshot.nextDate))
                    .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.6)
            }
        }
        .gaugeStyle(.accessoryCircular)
    }
}
