import ActivityKit
import Foundation

/// The Live Activity's shape.
///
/// **Add this file to the Runner and NoorWidgets targets** — the app starts and
/// updates the activity, the widget extension renders it, and both need the
/// same type.
struct PrayerActivityAttributes: ActivityAttributes {
    /// One prayer in the day's row.
    struct PrayerStop: Codable, Hashable {
        var key: String
        var label: String
        var at: Date
    }

    struct ContentState: Codable, Hashable {
        /// "Maghrib" — the next prayer, or the paused one while apps are locked.
        var prayerLabel: String

        /// When the countdown lands: the next prayer's time, or the end of
        /// the 30-minute pause while apps are locked.
        var endsAt: Date

        /// Today's five, so the activity can draw the times row.
        var prayers: [PrayerStop]

        /// True while apps are blocked and the prayer is unconfirmed.
        var locked: Bool

        /// The 30-minute window has passed and it is still unconfirmed.
        var overdue: Bool

        var completedToday: Int
        var totalToday: Int

        /// Reachable here and nowhere else on a free account: `Activity`
        /// carries state directly from the app, with no App Group in between.
        var streak: Int
    }

    /// Fixed for the life of the activity.
    var city: String
}
