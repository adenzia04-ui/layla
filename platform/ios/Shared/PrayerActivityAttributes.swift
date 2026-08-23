import ActivityKit
import Foundation

/// The Live Activity's shape.
///
/// **Add this file to the Runner and NoorWidgets targets** — the app starts and
/// updates the activity, the widget extension renders it, and both need the
/// same type.
struct PrayerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "Maghrib"
        var prayerLabel: String

        /// When the countdown lands.
        var endsAt: Date

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
