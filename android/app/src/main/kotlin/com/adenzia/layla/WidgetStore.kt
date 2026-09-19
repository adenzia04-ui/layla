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
        val latitude: Double,
        val longitude: Double,
        val prayers: List<Prayer>,
        val nextKey: String,
        val nextStartsAtSeconds: Long,
        val currentKey: String,
        val currentStartedAtSeconds: Long,
        val completedToday: Int,
        val totalToday: Int,
        val streak: Int,
        /** Keys of the prayers confirmed today — which, not how many. */
        val confirmed: Set<String>,
        val tasbihToday: Int,
        val theme: String,
        val updatedAtSeconds: Long,
    ) {
        /**
         * How far through the gap between the running prayer and the next one
         * we are, which is what the arc fills. Matches `progressAt` in
         * `lib/features/widgets/domain/widget_snapshot.dart`.
         */
        fun progressAt(nowSeconds: Long): Float {
            val span = nextStartsAtSeconds - currentStartedAtSeconds
            if (span <= 0) return 0f
            val done = nowSeconds - currentStartedAtSeconds
            return (done.toFloat() / span.toFloat()).coerceIn(0f, 1f)
        }

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
            val doneList = root.optJSONArray("confirmed") ?: JSONArray()
            val done = LinkedHashSet<String>(doneList.length())
            for (i in 0 until doneList.length()) {
                done.add(doneList.optString(i))
            }
            Snapshot(
                city = root.optString("city"),
                hijri = root.optString("hijri"),
                latitude = root.optDouble("latitude", 0.0),
                longitude = root.optDouble("longitude", 0.0),
                prayers = prayers,
                nextKey = root.optString("nextKey"),
                nextStartsAtSeconds = root.optLong("nextEpoch"),
                currentKey = root.optString("currentKey"),
                currentStartedAtSeconds = root.optLong("currentEpoch"),
                completedToday = root.optInt("completedToday"),
                totalToday = root.optInt("totalToday", 5),
                streak = root.optInt("streak"),
                confirmed = done,
                tasbihToday = root.optInt("tasbihToday"),
                theme = root.optString("theme", "midnight"),
                updatedAtSeconds = root.optLong("updatedAt"),
            )
        } catch (error: Exception) {
            null
        }
    }
}
