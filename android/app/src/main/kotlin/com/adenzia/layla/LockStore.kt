package com.adenzia.layla

import android.content.Context

/**
 * The little the Android lock has to remember, and nothing more.
 *
 * It lives in its own SharedPreferences file rather than Flutter's, because
 * every reader here runs when Flutter does not: an alarm receiver waking at
 * Fajr, a foreground service polling while the app is closed, the shield
 * drawn over somebody else's app. None of them can call into Dart.
 *
 * Which apps a person chose is the only sensitive thing stored, and it never
 * leaves the phone. The service reads the set to decide whether the app now
 * in front is one of them; it does not record what was opened, or when, or
 * for how long.
 */
object LockStore {
    private const val FILE = "layla_prayer_lock"
    private const val KEY_BLOCKED = "blocked_packages"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_WINDOWS = "windows"

    /** One prayer window: when the shield may rise, and when it must stop. */
    data class Window(val label: String, val startMs: Long, val endMs: Long)

    private fun prefs(context: Context) =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun blocked(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_BLOCKED, emptySet()) ?: emptySet()

    fun setBlocked(context: Context, packages: Set<String>) {
        // A fresh set: SharedPreferences hands back the live instance it
        // holds, and mutating that one is documented to be undefined.
        prefs(context).edit()
            .putStringSet(KEY_BLOCKED, LinkedHashSet(packages))
            .apply()
    }

    fun enabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ENABLED, false)

    fun setEnabled(context: Context, on: Boolean) {
        prefs(context).edit().putBoolean(KEY_ENABLED, on).apply()
    }

    /**
     * The day's windows, flattened to one string.
     *
     * A list of six short records does not deserve a database, and the
     * receiver that reads them has to be cheap: it runs at Fajr, on a phone
     * that has been asleep for hours, with a few hundred milliseconds of
     * wakelock to work with.
     */
    fun windows(context: Context): List<Window> =
        (prefs(context).getString(KEY_WINDOWS, "") ?: "")
            .split(';')
            .mapNotNull { row ->
                val parts = row.split('|')
                if (parts.size != 3) return@mapNotNull null
                val start = parts[1].toLongOrNull() ?: return@mapNotNull null
                val end = parts[2].toLongOrNull() ?: return@mapNotNull null
                Window(parts[0], start, end)
            }

    fun setWindows(context: Context, windows: List<Window>) {
        val flat = windows.joinToString(";") { w ->
            // The label is the only free text, and a separator inside it
            // would silently eat the two numbers after it.
            val label = w.label.replace('|', ' ').replace(';', ' ')
            "$label|${w.startMs}|${w.endMs}"
        }
        prefs(context).edit().putString(KEY_WINDOWS, flat).apply()
    }

    /** The window covering [at], if the lock is on and one is open. */
    fun openWindow(context: Context, at: Long = System.currentTimeMillis()):
        Window? {
        if (!enabled(context)) return null
        return windows(context).firstOrNull { at >= it.startMs && at < it.endMs }
    }
}
