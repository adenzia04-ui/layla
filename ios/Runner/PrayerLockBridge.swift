// Compiled only when NOOR_SCREEN_TIME is set in
// Build Settings → Swift Compiler – Custom Flags → Active Compilation
// Conditions.
//
// Without the flag this whole file is inert, so a plain `flutter run` works
// with no extra Xcode targets, no App Group and no Apple entitlement —
// AppDelegate answers the channel with an "unsupported" stub instead.
//
// See platform/ios/README.md.

#if NOOR_SCREEN_TIME

import Flutter
import UIKit

import DeviceActivity
import FamilyControls
import ManagedSettings
import SwiftUI

/// The app side of the iOS prayer lock: answers the same MethodChannel that
/// `AndroidSoftLock` uses, so `PrayerLockPlatform` in Dart never branches on
/// platform.
///
/// Everything degrades to "not supported" unless three things are true:
///   1. iOS 16 or later (`.individual` Screen Time authorisation).
///   2. `NoorScreenTimeEnabled` is `YES` in Info.plist.
///   3. The build carries the Family Controls (Distribution) entitlement.
///
/// (2) exists because (3) cannot be detected at runtime — flipping the plist
/// key is how you say "Apple granted it". Leaving it off means the settings
/// screen honestly reads "Not available on this device" instead of showing a
/// toggle that throws.
enum PrayerLockBridge {

    private static let channelName = "com.noorapp.noor/prayer_lock"

    static func register(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            handle(call: call, result: result, controller: controller)
        }
    }

    /// Set `NoorScreenTimeEnabled` to YES in Runner/Info.plist once the
    /// entitlement is on the provisioning profile.
    private static var screenTimeEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NoorScreenTimeEnabled")
            as? Bool ?? false
    }

    private static func handle(
        call: FlutterMethodCall,
        result: @escaping FlutterResult,
        controller: FlutterViewController
    ) {
        guard #available(iOS 16.0, *), screenTimeEnabled else {
            respondUnsupported(call: call, result: result)
            return
        }

        switch call.method {
        case "permissions":
            // Read on every foreground, which makes it the natural place to
            // notice a self-test whose window has expired.
            NoorLock.releaseExpiredTestShield()
            result([
                "supported": true,
                "authorized":
                    AuthorizationCenter.shared.authorizationStatus == .approved,
                // Blocking everything needs no picker selection at all.
                "hasSelection":
                    NoorLock.blockScope == "everything" || NoorLock.hasSelection,
            ])

        case "requestAuthorization":
            Task {
                do {
                    try await AuthorizationCenter.shared
                        .requestAuthorization(for: .individual)
                    await MainActor.run { result(true) }
                } catch {
                    NSLog("Noor: Screen Time authorisation failed — \(error)")
                    // The reason, not just "no".
                    //
                    // This used to return a bare false, so the settings screen
                    // showed a red cross and nothing else — and every cause
                    // below has a different fix. "Screen Time is off in iOS
                    // Settings" is a ten-second fix; the user just had no way
                    // to know that was the problem.
                    let reason = Self.authorisationReason(error)
                    await MainActor.run {
                        result(FlutterError(
                            code: "screentime-denied",
                            message: reason,
                            details: "\(error)"
                        ))
                    }
                }
            }

        case "chooseApps":
            presentPicker(from: controller, result: result)

        case "scheduleWindows":
            let arguments = call.arguments as? [String: Any]
            let windows = arguments?["windows"] as? [[String: Any]] ?? []
            let scope = arguments?["scope"] as? String ?? "everything"
            NoorLock.registerWindows(windows, scope: scope)
            result(nil)

        case "start":
            let arguments = call.arguments as? [String: Any]
            NoorLock.activePrayerLabel =
                arguments?["prayerLabel"] as? String ?? "Prayer"
            NoorLock.applyShield()
            result(true)

        case "stop":
            NoorLock.clearShield()
            result(true)

        case "startTestWindow":
            let end = NoorLock.startTestWindow()
            NoorLock.activePrayerLabel = "Test"
            var report = NoorLock.selfTestReport()
            report["endMillis"] = Int(end.timeIntervalSince1970 * 1000)
            result(report)

        case "startTriggerTest":
            let start = NoorLock.startTriggerTest()
            NoorLock.activePrayerLabel = "Trigger test"
            result(Int(start.timeIntervalSince1970 * 1000))

        // Android-only members of the shared interface.
        case "requestUsageAccess", "requestOverlay":
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static func respondUnsupported(
        call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "permissions":
            result([
                "supported": false,
                "authorized": false,
                "hasSelection": false,
            ])
        case "requestAuthorization", "chooseApps", "start", "stop":
            result(false)
        default:
            result(nil)
        }
    }

    /// Presents Apple's own picker. Noor never sees the chosen apps — the
    /// selection comes back as opaque tokens which we hand straight to the
    /// App Group without inspecting.
    @available(iOS 16.0, *)
    private static func presentPicker(
        from controller: UIViewController,
        result: @escaping FlutterResult
    ) {
        var host: UIHostingController<NoorActivityPickerView>?

        let view = NoorActivityPickerView(
            initial: NoorLock.loadSelection() ?? FamilyActivitySelection(),
            onDone: { selection in
                NoorLock.saveSelection(selection)
                host?.dismiss(animated: true) {
                    result(NoorLock.hasSelection)
                }
            },
            onCancel: {
                host?.dismiss(animated: true) {
                    result(NoorLock.hasSelection)
                }
            }
        )

        host = UIHostingController(rootView: view)
        guard let host else {
            result(false)
            return
        }
        // The one surface in this flow left at the platform default. The
        // shield beside it is themed to midnight, and SwiftUI otherwise
        // follows the device appearance — so on a phone set to Light this
        // slid a full-screen white sheet over an app that has no light mode.
        host.overrideUserInterfaceStyle = .dark
        controller.present(host, animated: true)
    }

    /// Plain English for the ways FamilyControls says no.
    @available(iOS 16.0, *)
    private static func authorisationReason(_ error: Error) -> String {
        guard let familyError = error as? FamilyControlsError else {
            return "Screen Time could not be enabled: "
                + error.localizedDescription
        }
        switch familyError {
        case .invalidAccountType:
            return "Turn Screen Time on first: iOS Settings \u{203A} Screen Time. "
                + "Layla Pro can only pause apps once iOS itself is managing them."
        case .authorizationCanceled:
            return "The Screen Time request was dismissed. Tap it again and "
                + "choose Continue."
        case .authorizationConflict:
            return "Another app already manages Screen Time on this phone. "
                + "Only one can, so Layla Pro cannot pause apps until that is removed."
        case .restricted:
            return "Screen Time is restricted on this phone \u{2014} usually a "
                + "Family Sharing or device management rule."
        case .networkError:
            return "Screen Time could not reach Apple. Check the connection "
                + "and try again."
        @unknown default:
            return "Screen Time refused the request: "
                + error.localizedDescription
        }
    }
}

@available(iOS 16.0, *)
struct NoorActivityPickerView: View {
    @State private var selection: FamilyActivitySelection

    let onDone: (FamilyActivitySelection) -> Void
    let onCancel: () -> Void

    init(
        initial: FamilyActivitySelection,
        onDone: @escaping (FamilyActivitySelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _selection = State(initialValue: initial)
        self.onDone = onDone
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Pause during prayer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onDone(selection) }
                    }
                }
        }
    }

}

#endif
