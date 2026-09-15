import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen and Dynamic Island presence: the next prayer counting down,
/// today's five beneath it, and the padlock while apps are paused.
///
/// Drawn on the system's own translucent material, tinted a little toward
/// night, so it sits among the other Lock Screen cards as one of them. It
/// used to be an opaque navy slab with an arch and a padlock inside it — the
/// one solid block on a screen of glass, and the first thing the eye went to
/// for the wrong reason.
struct PrayerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Layl.deepNavy.opacity(0.62))
                .activitySystemActionForegroundColor(Layl.pulseSoft)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        glyph(context, size: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            CapsLabel(
                                text: capsText(context),
                                color: context.state.locked ? Layl.ember : Layl.pulse
                            )
                            Text(context.state.prayerLabel)
                                .font(Layl.display(16))
                                .foregroundStyle(Layl.cream)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        countdown(context, size: 18)
                        tag(context)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        timesRow(context)
                        streak(context)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: context.state.locked ? "lock.fill" : symbol(context))
                    .foregroundStyle(context.state.locked ? Layl.ember : Layl.pulseSoft)
            } compactTrailing: {
                countdown(context, size: 13)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: symbol(context))
                    .foregroundStyle(Layl.pulseSoft)
            }
            .widgetURL(URL(string: "noor://focus"))
            .keylineTint(Layl.pulse)
        }
    }

    // MARK: - Lock Screen

    private func lockScreen(
        _ context: ActivityViewContext<PrayerActivityAttributes>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                glyph(context, size: 46)

                VStack(alignment: .leading, spacing: 2) {
                    CapsLabel(
                        text: capsText(context),
                        color: context.state.locked ? Layl.ember : Layl.pulse
                    )
                    Text(context.state.prayerLabel)
                        .font(Layl.display(22))
                        .foregroundStyle(Layl.cream)
                    Text(statusLine(context))
                        .font(Layl.ui(12))
                        .foregroundStyle(Layl.mist)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 0) {
                    countdown(context, size: 30)
                    tag(context)
                }
            }

            Rectangle()
                .fill(Layl.pulse.opacity(0.18))
                .frame(height: 1)

            HStack(spacing: 10) {
                timesRow(context)
                streak(context)
                LaylaBadge(size: 13)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Pieces

    /// The prayer's own glyph in a blue ring with a soft glow — the padlock
    /// only while apps are actually paused.
    private func glyph(
        _ context: ActivityViewContext<PrayerActivityAttributes>,
        size: CGFloat
    ) -> some View {
        let locked = context.state.locked
        let tint = locked ? Layl.ember : Layl.pulse
        return ZStack {
            Circle().fill(tint.opacity(0.16))
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.9), tint.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
            Image(systemName: locked ? "lock.fill" : symbol(context))
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(locked ? Layl.ember : Layl.pulseSoft)
        }
        .frame(width: size, height: size)
        .shadow(color: tint.opacity(0.35), radius: 8)
    }

    private func symbol(
        _ context: ActivityViewContext<PrayerActivityAttributes>
    ) -> String {
        switch context.state.prayerLabel.lowercased() {
        case "fajr": return "sparkles"
        case "dhuhr": return "sun.max.fill"
        case "asr": return "sun.min.fill"
        case "maghrib": return "sunset.fill"
        case "isha": return "moon.stars.fill"
        case "tahajjud": return "moon.zzz.fill"
        default: return "moon.fill"
        }
    }

    /// Counts down to the next prayer (or the end of the pause). Once it has
    /// landed the activity is stale and the number gives way to a word, so
    /// nobody is left looking at 00:00.
    private func countdown(
        _ context: ActivityViewContext<PrayerActivityAttributes>,
        size: CGFloat
    ) -> some View {
        Group {
            if context.state.overdue {
                Text(
                    timerInterval: context.state.endsAt...Date.distantFuture,
                    countsDown: false
                )
            } else if context.isStale || Date() >= context.state.endsAt {
                Text("Now")
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
        .foregroundStyle(context.state.overdue ? Layl.ember : Layl.cream)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .multilineTextAlignment(.trailing)
    }

    private func capsText(
        _ context: ActivityViewContext<PrayerActivityAttributes>
    ) -> String {
        if context.state.locked { return "Apps paused" }
        return context.isStale || Date() >= context.state.endsAt
            ? "Prayer time"
            : "Next prayer"
    }

    private func tag(
        _ context: ActivityViewContext<PrayerActivityAttributes>
    ) -> some View {
        Text(
            context.state.overdue
                ? "OVERDUE"
                : (context.isStale || Date() >= context.state.endsAt) ? "BEGUN" : "LEFT"
        )
            .font(Layl.ui(9, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(context.state.overdue ? Layl.ember : Layl.pulse.opacity(0.8))
    }

    /// Today's five, label over time, the next one lit. Replaces the old
    /// progress bar: the times are what someone glances at the Lock Screen
    /// for.
    private func timesRow(
        _ context: ActivityViewContext<PrayerActivityAttributes>
    ) -> some View {
        let next = context.state.prayers.first { $0.at > Date() }?.key
        return HStack(spacing: 0) {
            ForEach(context.state.prayers, id: \.key) { p in
                let lit = p.key == next
                VStack(spacing: 1) {
                    Text(p.label.uppercased())
                        .font(Layl.ui(8, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(lit ? Layl.pulse : Layl.mistFaint)
                    Text(p.at, style: .time)
                        .font(Layl.numeral(11, weight: lit ? .bold : .medium))
                        .foregroundStyle(lit ? Layl.pulseSoft : Layl.mist)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func streak(
        _ context: ActivityViewContext<PrayerActivityAttributes>
    ) -> some View {
        if context.state.streak > 0 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Layl.ember)
                Text("\(context.state.streak)")
                    .font(Layl.numeral(11, weight: .bold))
                    .foregroundStyle(Layl.cream)
            }
        }
    }

    private func statusLine(
        _ context: ActivityViewContext<PrayerActivityAttributes>
    ) -> String {
        if context.state.locked {
            return context.state.overdue
                ? "Confirm your prayer to unlock your apps"
                : "Your apps are paused until you confirm"
        }
        if context.isStale || Date() >= context.state.endsAt {
            return "\(context.state.prayerLabel) has begun"
        }
        return "Until \(context.state.prayerLabel)"
    }
}
