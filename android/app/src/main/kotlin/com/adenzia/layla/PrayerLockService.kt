package com.adenzia.layla

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log

/**
 * The Android half of the prayer lock, and the honest limits of it.
 *
 * While a prayer window is open this service polls which app is in the
 * foreground. When it is not Noor, it brings the prayer focus screen back —
 * which is only permitted because the user granted "display over other apps",
 * the grant that also lifts the background-activity-start restriction.
 *
 * What this deliberately does NOT do:
 *  - use an AccessibilityService (works, but is a Play Store policy problem)
 *  - record, store or transmit which apps the user opened
 *  - run outside an open prayer window
 *  - survive the user turning the feature off, force-stopping, or rebooting
 */
class PrayerLockService : Service() {

    companion object {
        const val ACTION_START = "com.adenzia.layla.LOCK_START"
        const val ACTION_STOP = "com.adenzia.layla.LOCK_STOP"
        const val EXTRA_LABEL = "prayerLabel"
        const val EXTRA_ENDS_AT = "endsAtMillis"

        private const val TAG = "NoorPrayerLock"
        private const val CHANNEL_ID = "prayer_focus_service"
        private const val NOTIFICATION_ID = 4711

        /** Long enough to be gentle on the battery, short enough to matter. */
        private const val POLL_INTERVAL_MS = 2_000L

        /** Don't re-launch more than once every few seconds. */
        private const val RELAUNCH_COOLDOWN_MS = 6_000L
    }

    private val handler = Handler(Looper.getMainLooper())
    private var endsAt: Long = 0
    private var label: String = "Prayer"
    private var lastRelaunch: Long = 0

    private val poll = object : Runnable {
        override fun run() {
            if (System.currentTimeMillis() >= endsAt) {
                stopSelf()
                return
            }
            checkForeground()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                label = intent.getStringExtra(EXTRA_LABEL) ?: "Prayer"
                endsAt = intent.getLongExtra(
                    EXTRA_ENDS_AT,
                    System.currentTimeMillis() + 30 * 60 * 1000L,
                )
                startForeground(NOTIFICATION_ID, buildNotification())
                handler.removeCallbacks(poll)
                handler.postDelayed(poll, POLL_INTERVAL_MS)
            }
        }
        // Deliberately not START_STICKY: if Android kills this, the user is
        // not silently re-locked later without context.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(poll)
        super.onDestroy()
    }

    private fun checkForeground() {
        val current = foregroundPackage() ?: return
        if (current == packageName) return
        // Home screen and the system UI are left alone — putting the phone
        // down is exactly what we want the user to do.
        if (current == launcherPackage() || current == "android") return

        val now = System.currentTimeMillis()
        if (now - lastRelaunch < RELAUNCH_COOLDOWN_MS) return
        lastRelaunch = now

        try {
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
                    )
                },
            )
        } catch (error: SecurityException) {
            // Background activity starts are blocked on some OEM builds even
            // with the overlay grant. Nothing to do but stay out of the way.
            Log.w(TAG, "could not return to Noor", error)
        }
    }

    /**
     * The most recent app to move to the foreground in the last 10 seconds.
     * Nothing is stored: the value is read, compared, and discarded.
     */
    private fun foregroundPackage(): String? {
        val usage = getSystemService(Context.USAGE_STATS_SERVICE)
            as? UsageStatsManager ?: return null
        val now = System.currentTimeMillis()
        val events = usage.queryEvents(now - 10_000, now)
        var latest: String? = null
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val isResume = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
            } else {
                @Suppress("DEPRECATION")
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
            }
            if (isResume) latest = event.packageName
        }
        return latest
    }

    private fun launcherPackage(): String? = packageManager
        .resolveActivity(
            Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
            0,
        )
        ?.activityInfo
        ?.packageName

    private fun buildNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Prayer focus",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    description =
                        "Shown while a prayer window is open and the soft " +
                        "lock is on."
                    setShowBadge(false)
                },
            )
        }

        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("$label — prayer focus is on")
            .setContentText("Tap to confirm your prayer.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentIntent(open)
            .setOngoing(true)
            .build()
    }
}
