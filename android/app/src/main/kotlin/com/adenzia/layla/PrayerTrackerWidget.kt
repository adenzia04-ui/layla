package com.adenzia.layla

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews

/**
 * The five, and which of them are done.
 *
 * The only widget that cannot work anything out for itself. Whether someone
 * *prayed* is a fact only the app knows, once a prayer is confirmed, so this
 * draws what the app wrote and nothing else: `confirmed` names the prayers,
 * one by one, and it is never stood in for by counting forward from
 * `completedToday` — a day where Fajr was missed and Dhuhr kept would come
 * out backwards.
 *
 * Handed nothing, handed yesterday, or handed a day with no prayers in it at
 * all, it says so rather than showing five empty circles that look like a bad
 * day.
 *
 * `internal` rather than private to this file on purpose: the redraw after a
 * confirmation comes from `PrayerWidgets.refreshAll`, which lives elsewhere
 * and needs to be able to call this. A tracker that only repaints when the
 * launcher happens to ask is a tracker that never changes.
 */
internal object PrayerTrackerPainter {

    private val CELLS = intArrayOf(
        R.id.tracker_cell0, R.id.tracker_cell1, R.id.tracker_cell2,
        R.id.tracker_cell3, R.id.tracker_cell4,
    )
    private val MARKS = intArrayOf(
        R.id.tracker_mark0, R.id.tracker_mark1, R.id.tracker_mark2,
        R.id.tracker_mark3, R.id.tracker_mark4,
    )
    private val NAMES = intArrayOf(
        R.id.tracker_name0, R.id.tracker_name1, R.id.tracker_name2,
        R.id.tracker_name3, R.id.tracker_name4,
    )

    private const val CONFIRMED_MARK = "✓"
    private const val OPEN_MARK = "○"

    fun paint(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_prayer_tracker)
        val snapshot = Chrome.snapshot(context)
        val palette = WidgetPalettes.named(snapshot?.theme)
        val now = Chrome.nowSeconds()

        Chrome.ground(views, R.id.widget_root, palette)
        Chrome.tap(context, views, R.id.widget_root)

        views.setTextColor(R.id.tracker_title, palette.gold)
        views.setTextColor(R.id.tracker_count, palette.cream)
        views.setTextColor(R.id.tracker_note, palette.mist)
        views.setTextColor(R.id.tracker_streak, palette.mist)
        views.setTextColor(R.id.tracker_next, palette.mistFaint)

        if (snapshot == null) {
            note(views, "Layla Pro", "Open the app and today's five will appear here.")
            return views
        }

        // Yesterday's ticks under today's heading would be a lie about the
        // one thing this widget is for, so the row goes rather than greys.
        if (snapshot.isStale(now)) {
            note(views, "Out of date", "These are not today's. Open Layla Pro to refresh.")
            return views
        }

        val obligatory = snapshot.prayers.filter { it.key != "sunrise" }

        // A snapshot can be today's and still carry no prayers — a day that
        // failed to compute, or a write that arrived half-formed. Drawing it
        // puts "0 of 5" and a live streak over a strip with nothing in it,
        // which reads as a day someone missed entirely rather than a day we
        // were never told about. That is the same lie the two guards above
        // exist to prevent, so it gets the same answer.
        if (obligatory.isEmpty()) {
            note(views, "Layla Pro", "Open the app and today's five will appear here.")
            return views
        }

        views.setViewVisibility(R.id.tracker_note, View.GONE)
        views.setViewVisibility(R.id.tracker_track, View.VISIBLE)
        views.setTextViewText(R.id.tracker_title, "Today's prayers")

        var confirmedCount = 0
        var drawnCount = 0

        for (slot in CELLS.indices) {
            val prayer = obligatory.getOrNull(slot)
            if (prayer == null) {
                views.setViewVisibility(CELLS[slot], View.GONE)
                continue
            }
            views.setViewVisibility(CELLS[slot], View.VISIBLE)
            drawnCount++

            val confirmed = snapshot.confirmed.contains(prayer.key)
            val isNext = prayer.key == snapshot.nextKey
            val past = prayer.startsAtSeconds in 1..now
            if (confirmed) confirmedCount++

            val ink = when {
                confirmed -> palette.cream
                isNext -> palette.gold
                past -> palette.mistFaint
                else -> palette.mist
            }

            views.setTextViewText(MARKS[slot], if (confirmed) CONFIRMED_MARK else OPEN_MARK)
            views.setTextViewText(NAMES[slot], prayer.label)
            views.setTextColor(MARKS[slot], ink)
            views.setTextColor(NAMES[slot], if (isNext) palette.cream else ink)
            views.setInt(
                CELLS[slot],
                "setBackgroundResource",
                if (isNext) palette.cellNext else palette.cell,
            )
        }

        // Both halves counted from the row that was actually drawn, so the
        // number at the top can never disagree with the cells under it.
        //
        // The denominator used to come from `snapshot.totalToday`, which is
        // the app's own constant five (`PrayerId.obligatory.length`) and is
        // what `WidgetStore.read` falls back to when the field is missing.
        // On any well-formed day the two agree; the only days they differ are
        // the malformed ones, and on those the row is the honest answer —
        // "4 of 5" printed over four cells is the widget arguing with itself.
        views.setTextViewText(R.id.tracker_count, "$confirmedCount of $drawnCount")

        views.setTextViewText(
            R.id.tracker_streak,
            if (snapshot.streak == 1) "1 day streak" else "${snapshot.streak} day streak",
        )

        val next = snapshot.prayers.firstOrNull { it.key == snapshot.nextKey }
        views.setTextViewText(
            R.id.tracker_next,
            if (next == null) {
                ""
            } else {
                "Next · ${next.label} ${Chrome.clock(context, snapshot.nextStartsAtSeconds)}"
            },
        )
        return views
    }

    /** Everything the widget cannot honestly draw, replaced by one sentence. */
    private fun note(views: RemoteViews, title: String, body: String) {
        views.setTextViewText(R.id.tracker_title, title)
        views.setTextViewText(R.id.tracker_count, "")
        views.setViewVisibility(R.id.tracker_track, View.GONE)
        views.setViewVisibility(R.id.tracker_note, View.VISIBLE)
        views.setTextViewText(R.id.tracker_note, body)
        views.setTextViewText(R.id.tracker_streak, "")
        views.setTextViewText(R.id.tracker_next, "")
    }
}

class PrayerTrackerWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        manager.updateAppWidget(ids, PrayerTrackerPainter.paint(context))
    }
}
