import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Constants and shield helpers shared by the app and both app extensions.
///
/// **Add this file to all three targets** (File Inspector → Target Membership:
/// Runner, NoorDeviceActivityMonitor, NoorShield). The three processes talk to
/// each other only through the App Group defaults and the named
/// `ManagedSettingsStore` below — there is no other channel between them.
@available(iOS 16.0, *)
enum NoorLock {

    /// Must match the App Group added to all three targets' entitlements.
    static let appGroup = "group.com.SMAG.noor"

    /// The store the shield is written to. Naming it keeps Noor's shield
    /// separate from anything else the user has configured in Screen Time.
    static let storeName = ManagedSettingsStore.Name("noorPrayerFocus")

    /// Every DeviceActivity Noor registers is prefixed, so the extensions can
    /// ignore activities belonging to other apps.
    static let activityPrefix = "noor.prayer."

    private static let selectionKey = "noor.shieldedSelection"
    private static let scopeKey = "noor.blockScope"
    private static let labelsKey = "noor.activityLabels"

    /// Fingerprint of the schedule already handed to DeviceActivity, so an
    /// unchanged re-register can be skipped. See `registerWindows`.
    private static let scheduleKey = "noor.scheduleSignature"
    private static let activeLabelKey = "noor.activePrayerLabel"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    // MARK: - The user's app selection
    //
    // `FamilyActivitySelection` holds opaque tokens. Noor cannot read which
    // apps they are, cannot log them, and cannot send them anywhere — iOS
    // deliberately does not expose that. All we can ask is whether the set is
    // empty.

    static func loadSelection() -> FamilyActivitySelection? {
        guard let data = defaults?.data(forKey: selectionKey) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults?.set(data, forKey: selectionKey)
    }

    static func clearSelection() {
        defaults?.removeObject(forKey: selectionKey)
    }

    static var hasSelection: Bool {
        guard let selection = loadSelection() else { return false }
        return !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }

    // MARK: - Scope

    /// "everything" shields the whole phone; anything else uses the user's
    /// picker selection.
    static var blockScope: String {
        get { defaults?.string(forKey: scopeKey) ?? "everything" }
        set { defaults?.set(newValue, forKey: scopeKey) }
    }


    // MARK: - Diagnostics

    /// Registers a real 16-minute DeviceActivity window starting a minute ago,
    /// so the system raises the shield immediately and drops it ~15 minutes
    /// later — the exact path a prayer takes.
    ///
    /// It exists because the prayer path can only be observed at a prayer
    /// boundary, which made every fix a guess verified hours later. This is not
    /// a simulation: same extension, same callbacks, same `ManagedSettingsStore`.
    /// If this works, the prayer window works.
    ///
    /// Sixteen minutes because DeviceActivity refuses intervals under fifteen,
    /// and starting a minute in the past is what makes the interval already
    /// open, so `intervalDidStart` fires now rather than tomorrow.
    @available(iOS 16.0, *)
    static func startTestWindow() -> Date {
        let center = DeviceActivityCenter()
        let name = DeviceActivityName(activityPrefix + "selftest")
        center.stopMonitoring([name])

        let now = Date()
        let start = now.addingTimeInterval(-60)
        let end = now.addingTimeInterval(15 * 60)
        let calendar = Calendar.current

        rememberLabels([name.rawValue: "Test"])

        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute], from: start),
            intervalEnd: calendar.dateComponents([.hour, .minute], from: end),
            repeats: false
        )

        do {
            try center.startMonitoring(name, during: schedule)
        } catch {
            NSLog("Noor: self-test window could not start — \(error)")
        }
        return end
    }

    // MARK: - The shield

    /// Raises the shield. Called by the extension when a prayer window opens,
    /// and by the app when it lands on the focus screen mid-window.
    static func applyShield() {
        let store = ManagedSettingsStore(named: storeName)

        if blockScope == "everything" {
            // `.all()` covers every app iOS permits shielding. Apple always
            // lets Phone, Messages and Settings through — emergency calls are
            // not something an app is allowed to take away, and shouldn't be.
            store.shield.applicationCategories =
                ShieldSettings.ActivityCategoryPolicy.all()
            store.shield.webDomainCategories =
                ShieldSettings.ActivityCategoryPolicy<WebDomain>.all()
            store.shield.applications = nil
            return
        }

        guard let selection = loadSelection() else { return }
        store.shield.applications =
            selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories =
            selection.categoryTokens.isEmpty
                ? nil
                : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
        store.shield.webDomains =
            selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
    }

    /// Drops the shield. Called when the window ends, and immediately when the
    /// user confirms a prayer — the reward for confirming is getting your
    /// phone back.
    static func clearShield() {
        let store = ManagedSettingsStore(named: storeName)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
    }

    // MARK: - Labels, so the shield screen can name the prayer

    static func rememberLabels(_ labels: [String: String]) {
        defaults?.set(labels, forKey: labelsKey)
    }

    static func label(for activity: DeviceActivityName) -> String {
        let labels = defaults?.dictionary(forKey: labelsKey) as? [String: String]
        return labels?[activity.rawValue] ?? "Prayer"
    }

    static var activePrayerLabel: String {
        get { defaults?.string(forKey: activeLabelKey) ?? "Prayer" }
        set { defaults?.set(newValue, forKey: activeLabelKey) }
    }

    // MARK: - Scheduling

    /// Registers today's prayer windows with DeviceActivity.
    ///
    /// The windows repeat daily on their hour and minute. Prayer times drift a
    /// few minutes each day, so Noor re-registers them every time the schedule
    /// is recomputed — but `repeats: true` means that if the app is not opened
    /// for a day or two, yesterday's near-enough times still fire rather than
    /// nothing at all.
    ///
    /// Passing an empty array is how the app turns the feature off: every Noor
    /// activity is stopped and the shield is dropped.
    static func registerWindows(_ windows: [[String: Any]], scope: String) {
        blockScope = scope
        let center = DeviceActivityCenter()

        // Re-registering an identical schedule is not free: `stopMonitoring`
        // during a live interval means `intervalDidEnd` never fires for it, so
        // the shield that went up at the start of this prayer would never come
        // down. The Dart side re-runs this whenever settings or times change,
        // which can easily land mid-window — so do nothing unless the schedule
        // has actually changed.
        let signature = windows
            .map { "\($0["id"] ?? "")@\($0["startMillis"] ?? "")-\($0["endMillis"] ?? "")" }
            .sorted()
            .joined(separator: ",") + "|" + scope
        let unchanged = defaults?.string(forKey: scheduleKey) == signature

        // Only ever touch our own activities.
        let ours = center.activities.filter {
            $0.rawValue.hasPrefix(activityPrefix)
        }

        if unchanged && !ours.isEmpty { return }

        if !ours.isEmpty { center.stopMonitoring(ours) }

        guard !windows.isEmpty else {
            defaults?.set(signature, forKey: scheduleKey)
            clearShield()
            return
        }

        defaults?.set(signature, forKey: scheduleKey)

        var labels: [String: String] = [:]
        let calendar = Calendar.current

        for window in windows {
            guard
                let id = window["id"] as? String,
                let startMillis = window["startMillis"] as? NSNumber,
                let endMillis = window["endMillis"] as? NSNumber
            else { continue }

            let start = Date(timeIntervalSince1970: startMillis.doubleValue / 1000)
            let end = Date(timeIntervalSince1970: endMillis.doubleValue / 1000)

            // DeviceActivity refuses intervals shorter than 15 minutes.
            guard end.timeIntervalSince(start) >= 15 * 60 else { continue }

            let name = DeviceActivityName(activityPrefix + id)
            labels[name.rawValue] = window["label"] as? String ?? "Prayer"

            let schedule = DeviceActivitySchedule(
                intervalStart: calendar.dateComponents([.hour, .minute], from: start),
                intervalEnd: calendar.dateComponents([.hour, .minute], from: end),
                repeats: true
            )

            do {
                try center.startMonitoring(name, during: schedule)
            } catch {
                NSLog("Noor: could not schedule \(name.rawValue) — \(error)")
            }
        }

        rememberLabels(labels)
    }

    /// Stops everything Noor registered and drops the shield.
    static func stopAll() {
        let center = DeviceActivityCenter()
        let ours = center.activities.filter {
            $0.rawValue.hasPrefix(activityPrefix)
        }
        if !ours.isEmpty { center.stopMonitoring(ours) }
        clearShield()
    }
}
