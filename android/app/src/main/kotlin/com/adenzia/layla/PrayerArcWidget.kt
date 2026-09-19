package com.adenzia.layla

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews

/**
 * The curved gauge, matching `ios/NoorWidgets/PrayerArcWidget.swift`.
 *
 * The arc fills from the prayer that just passed to the one coming, and the
 * two endpoints of that stretch are named beside it. The countdown is a
 * Chronometer, so it keeps ticking on its own; the arc is a still, and only
 * moves when the app pushes a new snapshot. That is the honest arrangement —
 * a widget cannot be woken often enough to animate a bitmap, and a gauge that
 * lagged by an hour while the clock beside it was right would be worse than
 * one that plainly waits for the app.
 */
private object PrayerArcPainter {

    /**
     * The bitmap the curve arrives as. Two-to-one because `Chrome.arc` draws
     * the top half of an ellipse as wide as the bitmap and twice as tall, so
     * anything else bends it out of a circle.
     */
    private const val ARC_WIDTH_PX = 480
    private const val ARC_HEIGHT_PX = 240

    /** Reads as the 9pt line of the iPhone gauge once scaled into 116dp. */
    private const val ARC_STROKE_PX = 30f

    fun paint(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_prayer_arc)
        val snapshot = Chrome.snapshot(context)
        val now = Chrome.nowSeconds()
        val palette = Chrome.palette(context)

        Chrome.ground(views, R.id.widget_root, palette)
        Chrome.tap(context, views, R.id.widget_root)

        views.setTextColor(R.id.arc_countdown, palette.cream)
        views.setTextColor(R.id.arc_until, palette.mist)
        views.setTextColor(R.id.arc_city, palette.cream)
        views.setTextColor(R.id.arc_now_label, palette.mist)
        views.setTextColor(R.id.arc_now_time, palette.mist)
        views.setTextColor(R.id.arc_next_label, palette.cream)
        views.setTextColor(R.id.arc_next_time, palette.cream)
        views.setTextColor(R.id.arc_note, palette.mist)
        views.setInt(R.id.arc_streak, "setBackgroundResource", palette.cell)
        views.setInt(R.id.arc_now_row, "setBackgroundResource", palette.cell)
        views.setInt(R.id.arc_next_row, "setBackgroundResource", palette.cellNext)

        if (snapshot == null) {
            gauge(views, 0f, palette)
            resting(views, "")
            views.setTextViewText(R.id.arc_city, "Layla Pro")
            views.setViewVisibility(R.id.arc_streak, View.GONE)
            note(views, "Open Layla Pro to see today's prayers.")
            return views
        }

        val stale = snapshot.isStale(now)
        views.setTextViewText(R.id.arc_city, snapshot.city)
        streak(views, snapshot, palette, stale)

        if (stale) {
            // Yesterday's fill would be a position on today's arc, so the
            // track is drawn empty rather than somewhere wrong.
            gauge(views, 0f, palette)
            resting(views, "Out of date")
            views.setTextColor(R.id.arc_until, palette.gold)
            note(views, "These are not today's. Open Layla Pro to refresh.")
            return views
        }

        // A snapshot can be fresh and still have no moment ahead of it:
        // `nextEpoch` is read with an implicit 0 default, so a write that
        // arrives without one leaves nothing to count down to and no far end
        // for the gauge to measure to. It has to be decided here rather than
        // left to Chrome.countdown — that stops the Chronometer and empties
        // it, but it cannot take back the visibilities this painter sets, so
        // the widget was left with a blank 20sp line under the arc, an
        // "until Fajr" caption counting towards nothing, and a lit next row
        // naming a prayer with an empty time beside it.
        if (snapshot.nextStartsAtSeconds <= 0) {
            gauge(views, 0f, palette)
            resting(views, "")
            note(views, "Nothing to count down to. Open Layla Pro to refresh.")
            return views
        }

        views.setViewVisibility(R.id.arc_note, View.GONE)
        views.setViewVisibility(R.id.arc_now_row, View.VISIBLE)
        views.setViewVisibility(R.id.arc_next_row, View.VISIBLE)

        gauge(views, progress(snapshot, now), palette)
        running(views, snapshot.nextStartsAtSeconds)

        val nextLabel = snapshot.prayers
            .firstOrNull { it.key == snapshot.nextKey }
            ?.label
            ?: "Prayer"
        views.setTextViewText(R.id.arc_until, "until $nextLabel")

        // Before Fajr nothing is running; the stretch being measured is the
        // night, which has a name but no start time to show.
        val current = snapshot.prayers.firstOrNull { it.key == snapshot.currentKey }
        views.setTextViewText(R.id.arc_now_label, current?.label ?: "Night")
        views.setTextViewText(
            R.id.arc_now_time,
            if (current == null) "" else Chrome.clock(context, current.startsAtSeconds),
        )

        views.setTextViewText(R.id.arc_next_label, nextLabel)
        views.setTextViewText(
            R.id.arc_next_time,
            Chrome.clock(context, snapshot.nextStartsAtSeconds),
        )
        return views
    }

    /**
     * How full the arc is drawn, or empty when there is no anchor to measure
     * from.
     *
     * `currentEpoch` is read with an implicit 0 default, and
     * `Snapshot.progressAt` divides by the span from it. A write that arrives
     * without one therefore does not read as "unknown": the span becomes the
     * whole of Unix time, `now` is very nearly all of it, and the gauge fills
     * to the brim. The app always writes one — before Fajr it anchors eight
     * hours back from Fajr rather than collapsing to zero, as
     * `widget_publisher.dart` does for iOS — so this guards a malformed write
     * rather than an ordinary night.
     */
    private fun progress(snapshot: WidgetStore.Snapshot, now: Long): Float =
        if (snapshot.currentStartedAtSeconds <= 0) 0f else snapshot.progressAt(now)

    /**
     * The countdown running, and the caption above the two rows left alone.
     *
     * This and [resting] are the only two places the Chronometer's visibility
     * is set, and every path through [paint] calls exactly one of them — so
     * the arc can never be left with a stopped, empty clock still holding its
     * line, which on a widget two cells tall is the "until" caption's worth of
     * height.
     */
    private fun running(views: RemoteViews, atSeconds: Long) {
        views.setViewVisibility(R.id.arc_countdown, View.VISIBLE)
        Chrome.countdown(views, R.id.arc_countdown, atSeconds)
    }

    /** The other half of [running]: no clock, and a caption of plain words. */
    private fun resting(views: RemoteViews, until: String) {
        Chrome.hideCountdown(views, R.id.arc_countdown)
        views.setViewVisibility(R.id.arc_countdown, View.GONE)
        views.setTextViewText(R.id.arc_until, until)
    }

    /**
     * Puts a line of plain English where the two endpoint rows go.
     *
     * The rows are hidden rather than blanked: an endpoint naming a prayer
     * with no time beside it reads as a time the widget has and is failing to
     * print, which is worse than an empty panel that says why.
     */
    private fun note(views: RemoteViews, text: String) {
        views.setViewVisibility(R.id.arc_now_row, View.GONE)
        views.setViewVisibility(R.id.arc_next_row, View.GONE)
        views.setViewVisibility(R.id.arc_note, View.VISIBLE)
        views.setTextViewText(R.id.arc_note, text)
    }

    /**
     * The track is the ink at 45% rather than a stored hairline colour: Sand
     * is a light set with dark ink, and a fixed pale track vanished on it.
     */
    private fun gauge(views: RemoteViews, fraction: Float, palette: Palette) {
        views.setImageViewBitmap(
            R.id.arc_gauge,
            Chrome.arc(
                ARC_WIDTH_PX,
                ARC_HEIGHT_PX,
                ARC_STROKE_PX,
                fraction,
                palette.mistFaint,
                palette.gold,
            ),
        )
    }

    /**
     * Only worth drawing when there is a run going. A stale record is dimmed
     * rather than hidden, so a number on screen is never quietly wrong.
     */
    private fun streak(
        views: RemoteViews,
        snapshot: WidgetStore.Snapshot,
        palette: Palette,
        stale: Boolean,
    ) {
        if (snapshot.streak <= 0) {
            views.setViewVisibility(R.id.arc_streak, View.GONE)
            return
        }
        views.setViewVisibility(R.id.arc_streak, View.VISIBLE)
        views.setTextViewText(
            R.id.arc_streak,
            if (snapshot.streak == 1) "1 day streak" else "${snapshot.streak} day streak",
        )
        views.setTextColor(
            R.id.arc_streak,
            if (stale) palette.mistFaint else palette.gold,
        )
    }
}

class PrayerArcWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        manager.updateAppWidget(ids, PrayerArcPainter.paint(context))
    }
}
