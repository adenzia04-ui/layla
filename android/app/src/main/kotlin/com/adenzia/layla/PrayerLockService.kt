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
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager

/**
 * The Android half of the prayer lock, and the honest limits of it.
 *
 * While a prayer window is open this service watches which app is in front.
 * When it is one the person chose to pause, it raises [PrayerShieldActivity]
 * over the top. That is as close to Apple's Screen Time shield as Android
 * allows a normal app to get, and the gap is real: the other app is visible
 * for a moment first, and anybody can leave.
 *
 * What this deliberately does NOT do:
 *  - use an AccessibilityService. It would detect the launch instantly rather
 *    than within a second, and Play does permit it with a declaration — but
 *    the policy asks for the narrowest API that achieves the job, and
 *    UsageStatsManager plainly achieves this one. It would also put every
 *    future release into extended review, and Android's Advanced Protection
 *    revokes it outright for the users who turn that on.
 *  - record, store or transmit which apps were opened. The foreground package
 *    is read, compared against the chosen set, and discarded.
 *  - run outside an open prayer window.
 *  - survive the person turning the feature off, force-stopping, or revoking
 *    either permission. All three are meant to work.
 */
class PrayerLockService : Service() {

    companion object {
        const val ACTION_START = "com.adenzia.layla.LOCK_START"
        const val ACTION_STOP = "com.adenzia.layla.LOCK_STOP"
        const val EXTRA_LABEL = "prayerLabel"
        const val EXTRA_ENDS_AT = "endsAtMillis"

        private const val TAG = "LaylaPrayerLock"
        private const val CHANNEL_ID = "prayer_focus_service"
        private const val NOTIFICATION_ID = 4711

        /**
         * Short enough that the paused app is on screen for about a second,
         * long enough that the poll costs little. Under a second the query
         * starts returning the same event repeatedly for no gain.
         */
        private const val POLL_INTERVAL_MS = 900L

        /** Don't stack shields if the person keeps trying the same app. */
        private const val RERAISE_COOLDOWN_MS = 4_000L
    }

    private val handler = Handler(Looper.getMainLooper())
    private var endsAt: Long = 0
    private var label: String = "Prayer"
    private var lastRaise: Long = 0
    private var anchor: View? = null

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
                if (endsAt <= System.currentTimeMillis()) {
                    stopSelf()
                    return START_NOT_STICKY
                }
                startForeground(NOTIFICATION_ID, buildNotification())
                addAnchor()
                handler.removeCallbacks(poll)
                handler.postDelayed(poll, POLL_INTERVAL_MS)
            }
        }
        // Deliberately not START_STICKY: if Android kills this, the user is
        // not silently re-locked later without context. The alarm chain in
        // PrayerWindowReceiver brings it back at the next edge instead.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(poll)
        removeAnchor()
        super.onDestroy()
    }

    /**
     * A one-pixel, untouchable overlay window, held for the length of the
     * window and nothing else.
     *
     * It draws nothing anybody can see. Its whole job is to be an overlay
     * window that exists, because from Android 10 a background process may
     * only start an Activity if it holds one — which is exactly what raising
     * the shield is. Without it the shield is refused on newer Android with a
     * SecurityException and the feature silently does nothing.
     */
    private fun addAnchor() {
        if (anchor != null) return
        if (!Settings.canDrawOverlaysCompat(this)) return
        val manager = getSystemService(WindowManager::class.java) ?: return
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            1,
            1,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.TOP or Gravity.START }

        val view = View(this)
        try {
            manager.addView(view, params)
            anchor = view
        } catch (error: Exception) {
            Log.w(TAG, "overlay anchor refused", error)
        }
    }

    private fun removeAnchor() {
        val view = anchor ?: return
        anchor = null
        try {
            getSystemService(WindowManager::class.java)?.removeView(view)
        } catch (error: Exception) {
            Log.w(TAG, "overlay anchor already gone", error)
        }
    }

    private fun checkForeground() {
        val current = foregroundPackage() ?: return
        if (current == packageName) return
        // Only the apps the person actually chose. An empty set pauses
        // nothing, which is the right answer for somebody who turned the
        // feature on and never picked anything.
        if (current !in LockStore.blocked(this)) return

        val now = System.currentTimeMillis()
        if (now - lastRaise < RERAISE_COOLDOWN_MS) return
        lastRaise = now

        try {
            startActivity(PrayerShieldActivity.intent(this, label, endsAt))
        } catch (error: SecurityException) {
            // Background activity starts are refused on some OEM builds even
            // with the overlay grant. Nothing to do but stay out of the way.
            Log.w(TAG, "could not raise the shield", error)
        }
    }

    /**
     * The most recent app to move to the foreground in the last few seconds.
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
                        "Shown while a prayer window is open and the apps " +
                        "you chose are paused."
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

/** Overlay permission, without dragging Settings into every file. */
private object Settings {
    fun canDrawOverlaysCompat(context: Context): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            android.provider.Settings.canDrawOverlays(context)
        } else {
            true
        }
}
