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
/// Note what is *not* here: no snapshot publishing, no map rendering. The home
/// screen widgets compute everything themselves, because handing them data
/// would need an App Group and that is a paid-membership capability.
///
/// Live Activities are the exception — `Activity.request` passes state straight
/// from the app to the system, with no shared container in between. That is why
/// the streak can appear on the Lock Screen but not in a home screen widget.
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

        // Widgets are self-computing now; the app has nothing to hand over.
        // Reloading timelines is still worth doing after a settings change.
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
        let label = (raw["lockedPrayerLabel"] as? String).flatMap {
            $0.isEmpty ? nil : $0
        } ?? "Prayer"
        let currentEpoch = raw["currentEpoch"] as? Int ?? 0
        let endsAt = Date(timeIntervalSince1970: TimeInterval(currentEpoch))
            .addingTimeInterval(30 * 60)

        let state = PrayerActivityAttributes.ContentState(
            prayerLabel: label,
            endsAt: endsAt,
            locked: raw["locked"] as? Bool ?? false,
            overdue: Date() > endsAt,
            completedToday: raw["completedToday"] as? Int ?? 0,
            totalToday: raw["totalToday"] as? Int ?? 5,
            streak: raw["streak"] as? Int ?? 0
        )

        let content = ActivityContent(
            state: state,
            // Let iOS retire it a few hours after the window, so a forgotten
            // activity does not sit on the Lock Screen indefinitely.
            staleDate: endsAt.addingTimeInterval(60 * 60 * 4)
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
