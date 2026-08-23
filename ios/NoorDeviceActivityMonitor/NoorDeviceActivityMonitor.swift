import DeviceActivity
import Foundation

/// Raises and drops the Screen Time shield at the edges of each prayer window.
///
/// This runs in its own process, woken by iOS — which is the whole point: the
/// shield works while Noor is closed, or force-quit, or the phone has been
/// rebooted since the schedule was registered.
///
/// Keep this file small. Extension processes get very little memory and are
/// killed without ceremony; anything slow here simply will not run.
@available(iOS 16.0, *)
class NoorDeviceActivityMonitor: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity.rawValue.hasPrefix(NoorLock.activityPrefix) else { return }

        NoorLock.activePrayerLabel = NoorLock.label(for: activity)
        NoorLock.applyShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity.rawValue.hasPrefix(NoorLock.activityPrefix) else { return }

        // The window is a deadline: 30 minutes after the prayer begins the
        // shield drops on its own, whether or not the prayer was confirmed.
        //
        // This runs in the extension rather than the app precisely because the
        // app may never be opened. An earlier design left the shield up until
        // both confirmation steps were done, and sleeping through Fajr meant a
        // phone locked all day — which pressures an honest user into
        // photographing a mat for a prayer they did not pray.
        //
        // Confirmation still matters, just not here: it is what feeds the
        // streak. The block is a nudge; the streak is the accountability.
        NoorLock.clearShield()
    }

    /// iOS warns shortly before an interval ends. Nothing to do, but
    /// overriding it stops the default implementation from being a surprise.
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }
}
