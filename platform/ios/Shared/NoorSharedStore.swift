import Foundation

/// The one channel between the app and its widget extension.
///
/// Prayer times are still computed inside the widget — they are a pure function
/// of location, date and method, so recomputing them is cheaper and more
/// reliable than shipping them across. What the widget genuinely *cannot* know
/// is anything that lives behind the user's login: the streak, and how much of
/// today has actually been confirmed. The app writes that here; the widget
/// reads it.
///
/// Add this file to both targets (Runner and NoorWidgetsExtension). The two
/// processes share nothing else.
enum NoorSharedStore {

    /// Must match `com.apple.security.application-groups` in both
    /// entitlements files. Note this is *not* derived from the bundle ID —
    /// App Group IDs are globally unique across all of Apple, and
    /// `group.com.noorapp.noor` was already taken by another team.
    static let appGroup = "group.com.SMAG.noor"

    private static let snapshotKey = "noor.widgetSnapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    /// What survives the trip. Deliberately small — anything the widget can
    /// work out for itself does not belong here.
    struct State {
        let streak: Int
        let completedToday: Int
        let totalToday: Int
        let updatedAt: Date

        /// The app writes on every snapshot change, so a stale record means
        /// Noor has not been opened in a while. Callers use this to decide
        /// whether the streak is still worth showing as fact.
        var isStale: Bool {
            Date().timeIntervalSince(updatedAt) > 36 * 60 * 60
        }
    }

    // MARK: - App side

    /// Called by `WidgetBridge` whenever the Dart snapshot changes.
    static func write(json: String) {
        defaults?.set(json, forKey: snapshotKey)
    }

    // MARK: - Widget side

    /// `nil` when the app has never published — a fresh install, or a user who
    /// has not signed in. Widgets must render sensibly in that case.
    static func read() -> State? {
        guard
            let json = defaults?.string(forKey: snapshotKey),
            let data = json.data(using: .utf8),
            let raw = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return nil }

        let updated = raw["updatedAt"] as? Int ?? 0

        return State(
            streak: raw["streak"] as? Int ?? 0,
            completedToday: raw["completedToday"] as? Int ?? 0,
            totalToday: raw["totalToday"] as? Int ?? 5,
            updatedAt: Date(timeIntervalSince1970: TimeInterval(updated))
        )
    }
}
