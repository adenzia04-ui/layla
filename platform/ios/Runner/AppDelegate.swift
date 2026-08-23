import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

    /// The channel Dart's `PrayerLockPlatform` talks to. It is answered here
    /// in every build — with the real Screen Time bridge when the integration
    /// is compiled in, and with an honest "unsupported" stub otherwise.
    private static let prayerLockChannel = "com.noorapp.noor/prayer_lock"
    private static let widgetChannel = "com.noorapp.noor/widgets"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        if let controller = window?.rootViewController as? FlutterViewController {
            #if NOOR_SCREEN_TIME
            PrayerLockBridge.register(with: controller)
            #else
            registerStubPrayerLock(with: controller)
            #endif

            #if NOOR_WIDGETS
            WidgetBridge.register(with: controller)
            #else
            registerStubWidgets(with: controller)
            #endif
        }

        return super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
    }

    #if !NOOR_SCREEN_TIME
    /// Default builds ship without the Screen Time integration, so that
    /// `flutter run` works on a plain checkout with no extra Xcode targets, no
    /// App Group, and no Apple entitlement.
    ///
    /// The channel still has to answer, or every call would hang on a
    /// `MissingPluginException`. Reporting `supported: false` is what makes the
    /// settings screen say "Not available on this device" instead of offering a
    /// toggle that cannot work.
    ///
    /// To compile the real thing in, follow `platform/ios/README.md`: add the
    /// extension targets, then add `NOOR_SCREEN_TIME` to
    /// *Build Settings → Swift Compiler – Custom Flags → Active Compilation
    /// Conditions*.
    private func registerStubPrayerLock(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: AppDelegate.prayerLockChannel,
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
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
    }
    #endif

    #if !NOOR_WIDGETS
    /// Default builds ship without the widget extension. The channel still has
    /// to answer or every publish would hang on a MissingPluginException, and
    /// the app would stall waiting for a widget that does not exist.
    private func registerStubWidgets(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: AppDelegate.widgetChannel,
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "liveActivitiesEnabled":
                result(false)
            default:
                result(nil)
            }
        }
    }
    #endif
}
