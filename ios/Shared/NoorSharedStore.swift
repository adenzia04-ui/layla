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
    static let appGroup = "group.com.adenzia.layla"

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

        /// Which prayers are confirmed today, by key ("fajr", "asr", ...).
        ///
        /// The counts alone cannot draw a tracker: "3 of 5" does not say
        /// *which* three, and a row of five ticks that guesses would be worse
        /// than no widget at all.
        let confirmed: Set<String>

        /// Today's tasbih count, for the counter widget.
        let tasbihToday: Int

        /// The colour set chosen in Settings — see `LaylPalette.named`.
        let theme: String

        /// Where the app says you are.
        ///
        /// The extension asks CoreLocation too, but the app only holds
        /// "When In Use" permission, so a widget refreshing in the background
        /// gets nil back and falls through to a default — which is how a
        /// phone in Selangor ended up showing Makkah's timetable on a
        /// Malaysian clock. The app knows the answer; it should just say it.
        let latitude: Double
        let longitude: Double
        let city: String
        let updatedAt: Date

        /// The app writes on every snapshot change, so a stale record means
        /// Noor has not been opened in a while. Callers use this to decide
        /// whether the streak is still worth showing as fact.
        var isStale: Bool {
            Date().timeIntervalSince(updatedAt) > 36 * 60 * 60
        }
    }

    // MARK: - App side

    /// Called by `WidgetBridge` whenever the Dart snapshot changes. Returns
    /// whether anything a widget draws actually differs from what was stored,
    /// so the caller can skip a reload for an identical snapshot.
    @discardableResult
    static func write(json: String) -> Bool {
        let before = defaults?.string(forKey: snapshotKey)
        defaults?.set(json, forKey: snapshotKey)
        guard let before else { return true }
        return strip(before) != strip(json)
    }

    /// The snapshot without its `updatedAt`, which changes on every write.
    private static func strip(_ json: String) -> String {
        guard
            let data = json.data(using: .utf8),
            var raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return json }
        raw["updatedAt"] = nil
        guard let out = try? JSONSerialization.data(withJSONObject: raw, options: [.sortedKeys]) else { return json }
        return String(decoding: out, as: UTF8.self)
    }

    // MARK: - The globe

    /// Where the app leaves the globe frame for the widget.
    ///
    /// A file in the App Group container rather than a value in UserDefaults:
    /// this is a few hundred KB of PNG, and UserDefaults is the wrong place
    /// for anything that size.
    private static var globeURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("layla_widget_globe.png")
    }

    static func writeGlobe(_ png: Data) {
        guard let url = globeURL else { return }
        try? png.write(to: url, options: .atomic)
    }

    /// `nil` until the app has drawn one. Widgets fall back to their own
    /// painted sky, which is the same palette without the sphere.
    static func readGlobe() -> Data? {
        guard let url = globeURL else { return nil }
        return try? Data(contentsOf: url)
    }

    // MARK: - Widget side

    /// Just the theme id, without parsing the rest of the snapshot. Read on
    /// every render, so it has to be cheap; "midnight" until the app has
    /// ever published.
    static func readTheme() -> String {
        guard
            let json = defaults?.string(forKey: snapshotKey),
            let data = json.data(using: .utf8),
            let raw = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return "midnight" }
        return raw["theme"] as? String ?? "midnight"
    }


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
            confirmed: Set(raw["confirmed"] as? [String] ?? []),
            tasbihToday: raw["tasbihToday"] as? Int ?? 0,
            theme: raw["theme"] as? String ?? "midnight",
            latitude: raw["latitude"] as? Double ?? 0,
            longitude: raw["longitude"] as? Double ?? 0,
            city: raw["city"] as? String ?? "",
            updatedAt: Date(timeIntervalSince1970: TimeInterval(updated))
        )
    }
}
