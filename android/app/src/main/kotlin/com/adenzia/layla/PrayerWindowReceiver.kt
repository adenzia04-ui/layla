package com.adenzia.layla

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Starts and stops the prayer focus at the right moment, with Flutter dead.
 *
 * This is the piece that was missing, and its absence meant the Android lock
 * had never run in a shipping build. The service was only ever started from
 * the prayer focus screen, which is reached from a route nothing navigated to
 * — so on Android the feature existed in full and was never once engaged.
 *
 * iOS does not need this: `DeviceActivity` hands the whole schedule to the
 * operating system and Apple raises the shield itself. Android has no such
 * thing, so the app has to book its own alarms and be woken by them.
 *
 * One alarm is armed at a time, for the next edge — the start of the next
 * window, or the end of the one that is open. Each firing arms the next. A
 * chain rather than six alarms because `setAlarmClock` is the only exact
 * alarm Doze reliably honours, and a phone should not carry six of them.
 */
class PrayerWindowReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "LaylaPrayerWindow"
        private const val REQUEST = 8801
        const val ACTION_EDGE = "com.adenzia.layla.WINDOW_EDGE"

        /**
         * Arms the alarm for the next edge after [from], and brings the
         * service into line with whatever is true right now.
         *
         * Safe to call as often as you like: it replaces the one alarm it
         * owns and starts or stops the service to match the clock.
         */
        fun reschedule(context: Context, from: Long = System.currentTimeMillis()) {
            val app = context.applicationContext
            val open = LockStore.openWindow(app, from)

            if (open != null) {
                app.startService(
                    Intent(app, PrayerLockService::class.java)
                        .setAction(PrayerLockService.ACTION_START)
                        .putExtra(PrayerLockService.EXTRA_LABEL, open.label)
                        .putExtra(PrayerLockService.EXTRA_ENDS_AT, open.endMs),
                )
            } else {
                app.startService(
                    Intent(app, PrayerLockService::class.java)
                        .setAction(PrayerLockService.ACTION_STOP),
                )
            }

            val next = nextEdge(app, from)
            val alarms = app.getSystemService(AlarmManager::class.java)
                ?: return
            val pending = PendingIntent.getBroadcast(
                app,
                REQUEST,
                Intent(app, PrayerWindowReceiver::class.java)
                    .setAction(ACTION_EDGE),
                PendingIntent.FLAG_IMMUTABLE or
                    PendingIntent.FLAG_UPDATE_CURRENT,
            )
            alarms.cancel(pending)
            if (next == null || !LockStore.enabled(app)) return

            try {
                // setAlarmClock, not setExactAndAllowWhileIdle: it is the one
                // kind Doze never defers, and it is honest — this is an alarm
                // the person set, for a time they chose, and the system may
                // show it as one.
                alarms.setAlarmClock(
                    AlarmManager.AlarmClockInfo(next, pending),
                    pending,
                )
            } catch (error: SecurityException) {
                // The exact-alarm grant can be withdrawn on Android 14+.
                // Inexact is late but not silent, which beats nothing.
                Log.w(TAG, "exact alarm refused; falling back", error)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarms.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        next,
                        pending,
                    )
                } else {
                    alarms.set(AlarmManager.RTC_WAKEUP, next, pending)
                }
            }
        }

        /** The soonest window start or end strictly after [from]. */
        private fun nextEdge(context: Context, from: Long): Long? =
            LockStore.windows(context)
                .flatMap { listOf(it.startMs, it.endMs) }
                .filter { it > from }
                .minOrNull()
    }

    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            // A reboot or an update clears every alarm the app had booked.
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            ACTION_EDGE,
            -> reschedule(context)
        }
    }
}
