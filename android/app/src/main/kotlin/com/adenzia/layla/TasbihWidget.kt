package com.adenzia.layla

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.widget.RemoteViews
import java.util.Calendar

/**
 * Today's dhikr count, as `TasbihWidgetView` in
 * `ios/NoorWidgets/LauncherWidgets.swift` draws it.
 *
 * The count is whatever the app last wrote; nothing here adds to it. A widget
 * that incremented on tap would be counting in a process that cannot hear the
 * haptics or the tally the Tasbih screen keeps, so the tap opens that screen
 * instead — which is what the hint promises.
 */
private object TasbihPainter {

    /**
     * What iOS shows in place of a number it cannot vouch for. Both the
     * never-run case and the stale one land here: a count is a tally of a
     * particular day, and yesterday's drawn plainly reads as today's.
     */
    private const val UNKNOWN = "—"

    /**
     * The counter itself — `Routes.tasbihCounter` in
     * `lib/core/routing/routes.dart`.
     *
     * Three slashes, not two. In `layla://tasbih` the word after the slashes
     * is the *host* and the path is empty, and go_router folds a pathless
     * link onto the splash route — the tap opened the app wherever it had
     * been, never the counter, while the hint underneath promised otherwise.
     * The empty authority in `layla:///…` leaves the whole route in the path,
     * which is what the Dart side matches on, and the manifest's scheme-only
     * intent filter accepts it either way.
     */
    private const val DEEP_LINK = "layla:///tasbih/counter"

    fun paint(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_tasbih)
        val snapshot = Chrome.snapshot(context)
        val palette = Chrome.palette(context)
        val now = Chrome.nowSeconds()

        Chrome.ground(views, R.id.widget_root, palette)
        views.setTextColor(R.id.tasbih_header, palette.gold)
        views.setTextColor(R.id.tasbih_count, palette.cream)
        views.setTextColor(R.id.tasbih_caption, palette.mist)
        views.setTextColor(R.id.tasbih_hint, palette.mistFaint)
        views.setImageViewBitmap(R.id.tasbih_bead, bead(context, palette))

        // A null snapshot is not "out of date" — the app has simply never
        // run — so it keeps the plain header and only the body says so.
        val stale = snapshot != null &&
            (snapshot.isStale(now) || !sameDay(snapshot.updatedAtSeconds, now))

        // The header carries the staleness, as it does on the prayer widgets,
        // so the line under the number stays free to say what to do about it.
        views.setTextViewText(R.id.tasbih_header, if (stale) "Out of date" else "Tasbih")

        if (snapshot != null && !stale) {
            views.setTextViewText(R.id.tasbih_count, snapshot.tasbihToday.toString())
            views.setTextViewText(R.id.tasbih_caption, "dhikr today")
        } else {
            views.setTextViewText(R.id.tasbih_count, UNKNOWN)
            views.setTextViewText(R.id.tasbih_caption, "Open Layla Pro to sync")
        }
        views.setTextViewText(R.id.tasbih_hint, "Tap to count")

        Chrome.tap(context, views, R.id.widget_root, DEEP_LINK)
        return views
    }

    /**
     * Whether two moments fall on the same local calendar day.
     *
     * `Snapshot.isStale` is an elapsed-time test — twenty hours — despite
     * describing itself as a day check. That is close enough for prayer
     * times, which drift by minutes between one day and the next, and wrong
     * for a tally that empties at midnight: a snapshot written at 22:00 is
     * ten hours old at 08:00 the following morning, so `isStale` is false
     * and the widget prints yesterday's total under "dhikr today" with no
     * hint that the day has turned over.
     *
     * The check sits here rather than in `WidgetStore` because seven other
     * widgets share `isStale` and none of them are scoped to a single day
     * this way; changing it underneath them is a wider decision than this
     * widget gets to make.
     */
    private fun sameDay(aSeconds: Long, bSeconds: Long): Boolean {
        val a = Calendar.getInstance().apply { timeInMillis = aSeconds * 1000 }
        val b = Calendar.getInstance().apply { timeInMillis = bSeconds * 1000 }
        return a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
            a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
    }

    /**
     * The mark beside the hint, where iOS has an SF Symbol.
     *
     * RemoteViews draws no shape of its own and cannot tint a drawable, so
     * anything that has to follow the chosen set arrives as a bitmap. A small
     * ring is the nearest mark to the symbol's cluster of beads.
     */
    private fun bead(context: Context, palette: Palette): Bitmap {
        val size = (10f * context.resources.displayMetrics.density).toInt()
            .coerceAtLeast(8)
        return Chrome.ring(
            sizePx = size,
            strokePx = size / 4f,
            fraction = 1f,
            trackColor = palette.goldDim,
            litColor = palette.goldDim,
        )
    }
}

class TasbihWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        manager.updateAppWidget(ids, TasbihPainter.paint(context))
    }
}
