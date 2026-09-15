// Compiled only when NOOR_WIDGETS is set in
// Build Settings → Swift Compiler – Custom Flags → Active Compilation
// Conditions.
//
// See platform/ios/README.md.

#if NOOR_WIDGETS

import ActivityKit
import Flutter
import UIKit
import WidgetKit

/// App side of the Live Activity.
///
/// The home screen widgets still compute prayer times themselves — a pure
/// function of location, date and method, so recomputing beats shipping data
/// across and the two can never drift. What they cannot know is anything
/// behind the login: `publishSnapshot` writes the streak and today's confirmed
/// count into the App Group for them.
///
/// Live Activities need no container at all — `Activity.request` passes state
/// straight from the app to the system.
enum WidgetBridge {

    private static let channelName = "com.noorapp.noor/widgets"

    static func register(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            handle(call: call, result: result)
        }
    }

    private static func handle(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        let args = call.arguments as? [String: Any]

        switch call.method {
        case "liveActivitiesEnabled":
            if #available(iOS 16.2, *) {
                result(ActivityAuthorizationInfo().areActivitiesEnabled)
            } else {
                result(false)
            }

        case "startLiveActivity", "updateLiveActivity":
            guard
                #available(iOS 16.2, *),
                let json = args?["snapshot"] as? String
            else {
                result(false)
                return
            }
            startOrUpdate(json: json)
            result(true)

        case "endLiveActivity":
            if #available(iOS 16.2, *) { endAll() }
            result(true)

        // Widgets still compute prayer times themselves — that is cheaper and
        // cannot drift. This hands over only what they cannot know: the
        // streak, and today's confirmed count.
        case "publishSnapshot":
            guard let json = args?["snapshot"] as? String else {
                result(false)
                return
            }
            // Redraw only when the widget-visible part changed. WidgetKit
            // budgets reloads per day; spending them on identical snapshots
            // left nothing for the rebuild that mattered.
            let changed = NoorSharedStore.write(json: json)
            if changed { WidgetCenter.shared.reloadAllTimelines() }
            result(true)

        case "publishGlobe":
            guard let data = args?["png"] as? FlutterStandardTypedData else {
                result(false)
                return
            }
            NoorSharedStore.writeGlobe(data.data)
            // The globe turns slowly; one redraw every half hour is plenty.
            let key = "noor.widget.globeReloadAt"
            let last = UserDefaults.standard.double(forKey: key)
            if Date().timeIntervalSince1970 - last > 30 * 60 {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
                WidgetCenter.shared.reloadAllTimelines()
            }
            result(true)

        case "reloadWidgets":
            WidgetCenter.shared.reloadAllTimelines()
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Live Activity

    @available(iOS 16.2, *)
    private static func startOrUpdate(json: String) {
        guard
            ActivityAuthorizationInfo().areActivitiesEnabled,
            let data = json.data(using: .utf8),
            let raw = try? JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else { return }

        let city = raw["city"] as? String ?? ""
        let locked = raw["locked"] as? Bool ?? false
        let prayers: [PrayerActivityAttributes.PrayerStop] =
            ((raw["prayers"] as? [[String: Any]]) ?? []).compactMap { p in
                guard let key = p["key"] as? String, let label = p["label"] as? String,
                      let epoch = p["epoch"] as? Int else { return nil }
                return .init(key: key, label: label, at: Date(timeIntervalSince1970: TimeInterval(epoch)))
            }
        let nextKey = raw["nextKey"] as? String ?? ""
        let nextAt = Date(timeIntervalSince1970: TimeInterval(raw["nextEpoch"] as? Int ?? 0))
        let nextLabel = prayers.first { $0.key == nextKey }?.label ?? "Prayer"

        // While apps are paused the countdown is the pause; otherwise it is
        // the next prayer, and the activity goes stale the moment it lands
        // so the view can say so instead of sitting at 00:00.
        let label: String
        let endsAt: Date
        if locked {
            label = (raw["lockedPrayerLabel"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? nextLabel
            let currentEpoch = raw["currentEpoch"] as? Int ?? 0
            endsAt = Date(timeIntervalSince1970: TimeInterval(currentEpoch)).addingTimeInterval(30 * 60)
        } else {
            label = nextLabel
            endsAt = nextAt
        }

        let state = PrayerActivityAttributes.ContentState(
            prayerLabel: label,
            endsAt: endsAt,
            prayers: prayers,
            locked: locked,
            overdue: locked && Date() > endsAt,
            completedToday: raw["completedToday"] as? Int ?? 0,
            totalToday: raw["totalToday"] as? Int ?? 5,
            streak: raw["streak"] as? Int ?? 0
        )

        let content = ActivityContent(
            state: state,
            staleDate: locked ? endsAt.addingTimeInterval(60 * 60 * 4) : endsAt
        )

        if let existing = Activity<PrayerActivityAttributes>.activities.first {
            Task { await existing.update(content) }
            return
        }

        do {
            _ = try Activity.request(
                attributes: PrayerActivityAttributes(city: city),
                content: content,
                pushType: nil
            )
        } catch {
            NSLog("Noor: could not start Live Activity — \(error)")
        }
    }

    @available(iOS 16.2, *)
    private static func endAll() {
        for activity in Activity<PrayerActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}

#endif
