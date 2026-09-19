package com.adenzia.layla

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * What the home-screen widgets know, and where it comes from.
 *
 * iOS widgets recompute prayer times themselves from the location and the
 * calculation method, using the same Adhan maths as the app, so the two can
 * never drift. Doing that on Android would mean porting the whole library to
 * Kotlin for a second implementation to keep in step, which is a good way to
 * end up with a widget that quietly disagrees with the app.
 *
 * So the app writes the day it has already computed, and the widget draws it.
 * The cost is honesty about staleness: if the app has not run today, the
 * widget is showing yesterday, and it says so rather than pretending.
 */
object WidgetStore {
    private const val FILE = "layla_widgets"
    private const val KEY_SNAPSHOT = "snapshot"

    /** One prayer, as the widget draws it. */
    data class Prayer(
        val key: String,
        val label: String,
        val startsAtSeconds: Long,
    )

    data class Snapshot(
        val city: String,
        val hijri: String,
        val prayers: List<Prayer>,
        val nextKey: String,
        val nextStartsAtSeconds: Long,
        val completedToday: Int,
        val totalToday: Int,
        val streak: Int,
        val theme: String,
        val updatedAtSeconds: Long,
    ) {
        /**
         * Whether this was written on a different day to the one being drawn.
         *
         * Not a clock comparison to the minute: a widget redrawn at 00:05 is
         * showing yesterday's times and should say so, even though it was
         * written five minutes ago.
         */
        fun isStale(nowSeconds: Long): Boolean =
            nowSeconds - updatedAtSeconds > 20 * 60 * 60
    }

    fun write(context: Context, json: String) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SNAPSHOT, json)
            .apply()
    }

    fun read(context: Context): Snapshot? {
        val raw = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(KEY_SNAPSHOT, null) ?: return null
        return try {
            val root = JSONObject(raw)
            val list = root.optJSONArray("prayers") ?: JSONArray()
            val prayers = ArrayList<Prayer>(list.length())
            for (i in 0 until list.length()) {
                val p = list.optJSONObject(i) ?: continue
                prayers.add(
                    Prayer(
                        key = p.optString("key"),
                        label = p.optString("label"),
                        startsAtSeconds = p.optLong("epoch"),
                    ),
                )
            }
            Snapshot(
                city = root.optString("city"),
                hijri = root.optString("hijri"),
                prayers = prayers,
                nextKey = root.optString("nextKey"),
                nextStartsAtSeconds = root.optLong("nextEpoch"),
                completedToday = root.optInt("completedToday"),
                totalToday = root.optInt("totalToday", 5),
                streak = root.optInt("streak"),
                theme = root.optString("theme", "midnight"),
                updatedAtSeconds = root.optLong("updatedAt"),
            )
        } catch (error: Exception) {
            null
        }
    }
}
