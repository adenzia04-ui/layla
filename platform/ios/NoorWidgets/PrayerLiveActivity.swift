import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island presence for an open prayer window.
///
/// Only alive while a window is open — a permanent Live Activity would be
/// clutter, and iOS would eventually cull it anyway.
struct PrayerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Layl.midnight)
                .activitySystemActionForegroundColor(Layl.gold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.prayerLabel)
                            .font(Layl.display(15))
                            .foregroundStyle(Layl.goldSoft)
                    } icon: {
                        Image(systemName: context.state.locked
                            ? "lock.fill"
                            : "moon.stars.fill")
                            .foregroundStyle(Layl.gold)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context, size: 17)
                        .foregroundStyle(Layl.cream)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        pips(context)
                        Text(statusLine(context))
                            .font(Layl.ui(11))
                            .foregroundStyle(Layl.mist)
                            .multilineTextAlignment(.center)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.locked
                    ? "lock.fill"
                    : "moon.stars.fill")
                    .foregroundStyle(Layl.gold)
            } compactTrailing: {
                countdown(context, size: 13)
                    .foregroundStyle(Layl.cream)
                    .frame(maxWidth: 48)
            } minimal: {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(Layl.gold)
            }
            .widgetURL(URL(string: "noor://focus"))
            .keylineTint(Layl.gold)
        }
    }

    // MARK: - Lock Screen

    private func lockScreen(
        _ context: ActivityViewContext<PrayerActivityAttributes>
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                MihrabShape()
                    .stroke(Layl.goldDim, lineWidth: 1)
                Image(systemName: context.state.locked
                    ? "lock.fill"
                    : "moon.stars.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Layl.gold)
            }
            .frame(width: 34, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.prayerLabel)
                    .font(Layl.display(18))
                    .foregroundStyle(Layl.cream)
                Text(statusLine(context))
                    .font(Layl.ui(11))
                    .foregroundStyle(Layl.mist)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    pips(context)
                    if context.state.streak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Layl.ember)
                            Text("\(context.state.streak)")
                                .font(Layl.numeral(10))
                                .foregroundStyle(Layl.mist)
                        }
                    }
                }
                .padding(.top, 3)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 1) {
                countdown(context, size: 22)
                    .foregroundStyle(Layl.cream)
                Text(context.state.overdue ? "overdue" : "left")
                    .font(Layl.ui(10))
                    .foregroundStyle(
                        context.state.overdue ? Layl.ember : Layl.mistFaint
                    )
            }
        }
        .padding(14)
    }

    // MARK: - Pieces

    /// Counts down while the window runs, then counts *up* once overdue — a
    /// countdown frozen at 00:00 reads as broken.
    private func countdown(
        _ context: ActivityViewContext<PrayerActivityAttributes>,
        size: CGFloat
    ) -> some View {
        Group {
            if context.state.overdue {
                Text(
                    timerInterval: context.state.endsAt...Date
                        .distantFuture,
                    countsDown: false
                )
            } else {
                Text(
                    timerInterval: Date()...max(
                        context.state.endsAt,
                        Date().addingTimeInterval(1)
                    ),
                    countsDown: true
                )
            }
        }
        .font(Layl.numeral(size, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    private func pips(
        _ context: ActivityViewContext<PrayerActivityAttributes>
    ) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<max(context.state.totalToday, 1), id: \.self) { i in
                Capsule()
                    .fill(
                        i < context.state.completedToday
                            ? Layl.emerald
                            : Layl.navyLine
                    )
                    .frame(width: 14, height: 3)
            }
        }
    }

    private func statusLine(
        _ context: ActivityViewContext<PrayerActivityAttributes>
    ) -> String {
        if context.state.locked {
            return context.state.overdue
                ? "Apps paused — confirm to unlock"
                : "Apps paused during this window"
        }
        return context.state.overdue
            ? "Still unconfirmed"
            : "Time to pray"
    }
}
