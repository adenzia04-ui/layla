package com.adenzia.layla

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The day as a list, matching `ios/NoorWidgets/PrayerListWidget.swift` at its
 * large size: the dates and the countdown above, then a row per prayer.
 *
 * The iPhone rows carry an SF Symbol saying what time of day each prayer is.
 * Android ships no such glyph set and a widget cannot draw one without a
 * bitmap per row per redraw, so the lit cell and the dimming carry the whole
 * of that job here: the next prayer sits on the lit ground, the ones already
 * behind us fade to mistFaint, and the rest are simply quiet.
 */
private object PrayerListPainter {

    private val ROWS = intArrayOf(
        R.id.pl_row0, R.id.pl_row1, R.id.pl_row2,
        R.id.pl_row3, R.id.pl_row4, R.id.pl_row5,
    )
    private val NAMES = intArrayOf(
        R.id.pl_row0_name, R.id.pl_row1_name, R.id.pl_row2_name,
        R.id.pl_row3_name, R.id.pl_row4_name, R.id.pl_row5_name,
    )
    private val TIMES = intArrayOf(
        R.id.pl_row0_time, R.id.pl_row1_time, R.id.pl_row2_time,
        R.id.pl_row3_time, R.id.pl_row4_time, R.id.pl_row5_time,
    )

    fun paint(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_prayer_list)
        val palette = Chrome.palette(context)
        val snapshot = Chrome.snapshot(context)
        val now = Chrome.nowSeconds()

        Chrome.ground(views, R.id.widget_root, palette)
        views.setTextColor(R.id.pl_next_label, palette.gold)
        views.setTextColor(R.id.pl_next_name, palette.gold)
        views.setTextColor(R.id.pl_countdown, palette.cream)
        views.setTextColor(R.id.pl_note, palette.mist)
        views.setTextColor(R.id.pl_hijri, palette.cream)
        views.setTextColor(R.id.pl_date, palette.mist)

        // The phone's own date, so it is right even when nothing has been
        // stored yet — it is the prayer times that go stale, not the calendar.
        views.setTextViewText(R.id.pl_date, today())

        Chrome.tap(context, views, R.id.widget_root)

        if (snapshot == null) {
            views.setTextViewText(R.id.pl_next_label, "Layla Pro")
            views.setTextViewText(R.id.pl_next_name, "")
            views.setTextViewText(R.id.pl_hijri, "")
            for (row in ROWS) views.setViewVisibility(row, View.GONE)
            note(views, "Open the app to see today's prayers.")
            return views
        }

        val stale = snapshot.isStale(now)

        // A snapshot can be fresh and still have no moment ahead of it:
        // `nextEpoch` is read with an implicit 0 default, so a write that
        // arrives without one leaves nothing to count down to. That is a
        // third case beside "no snapshot" and "yesterday's", and it has to
        // be decided here rather than inside Chrome.countdown — that stops
        // the Chronometer and empties it, but it cannot take back a
        // visibility this file has already set, so the panel was left with
        // a blank 24sp line exactly where the time belongs.
        val counting = !stale && snapshot.nextStartsAtSeconds > 0

        views.setTextViewText(R.id.pl_next_label, if (stale) "Out of date" else "Next")
        views.setTextViewText(
            R.id.pl_next_name,
            if (counting) {
                snapshot.prayers.firstOrNull { it.key == snapshot.nextKey }?.label ?: ""
            } else {
                ""
            },
        )
        // The Gregorian line under this one is the phone's own and is always
        // today's. A Hijri date carried over from yesterday's snapshot would
        // sit directly above it, two different days in the same corner with
        // the older one reading as today — which is the dishonesty the stale
        // path exists to avoid.
        views.setTextViewText(R.id.pl_hijri, if (stale) "" else snapshot.hijri)

        when {
            stale -> note(views, "These are not today's. Open Layla Pro to refresh.")
            !counting -> note(views, "Nothing to count down to. Open Layla Pro to refresh.")
            else -> countdown(views, snapshot.nextStartsAtSeconds)
        }

        for (slot in ROWS.indices) {
            val prayer = snapshot.prayers.getOrNull(slot)
            if (prayer == null) {
                // Shurooq is the sixth only when the app sent it. An empty row
                // drawn anyway is a blank tile below real ones; hidden, the
                // list simply ends where the day's prayers do.
                views.setViewVisibility(ROWS[slot], View.GONE)
                continue
            }
            views.setViewVisibility(ROWS[slot], View.VISIBLE)
            // The same `counting` the header uses, so a lit "next" row can
            // never appear under a note that says there is nothing ahead.
            val isNext = counting && prayer.key == snapshot.nextKey
            // Yesterday's times are all behind us, and dimming every row would
            // read as "the day is over" rather than "this is the wrong day".
            val past = !stale && prayer.startsAtSeconds <= now && !isNext

            views.setTextViewText(NAMES[slot], prayer.label)
            views.setTextViewText(TIMES[slot], Chrome.clock(context, prayer.startsAtSeconds))
            views.setTextColor(
                NAMES[slot],
                when {
                    isNext -> palette.cream
                    past -> palette.mistFaint
                    else -> palette.mist
                },
            )
            views.setTextColor(
                TIMES[slot],
                when {
                    isNext -> palette.gold
                    past -> palette.mistFaint
                    else -> palette.cream
                },
            )
            views.setInt(
                ROWS[slot],
                "setBackgroundResource",
                if (isNext) palette.cellNext else palette.cell,
            )
        }
        return views
    }

    /**
     * Puts a line of plain English where the countdown goes.
     *
     * The Chronometer has to be hidden as well as stopped: left visible and
     * empty it still reserves its line, and on a widget already three cells
     * tall that line costs the last prayer in the list.
     *
     * This and [countdown] are the only two places either visibility is set,
     * and every path through the painter calls exactly one of them — so the
     * panel can never end up showing both, or neither.
     */
    private fun note(views: RemoteViews, text: String) {
        Chrome.hideCountdown(views, R.id.pl_countdown)
        views.setViewVisibility(R.id.pl_countdown, View.GONE)
        views.setViewVisibility(R.id.pl_note, View.VISIBLE)
        views.setTextViewText(R.id.pl_note, text)
    }

    /** The other half of [note]: the running clock, and no line of prose. */
    private fun countdown(views: RemoteViews, atSeconds: Long) {
        views.setViewVisibility(R.id.pl_note, View.GONE)
        views.setViewVisibility(R.id.pl_countdown, View.VISIBLE)
        Chrome.countdown(views, R.id.pl_countdown, atSeconds)
    }

    /**
     * Weekday, day, month and year, in the order the person's locale writes
     * them — a fixed pattern would print an American date in Germany.
     */
    private fun today(): String {
        val locale = Locale.getDefault()
        val pattern = DateFormat.getBestDateTimePattern(locale, "EEEdMMMy")
        return SimpleDateFormat(pattern, locale).format(Date())
    }
}

class PrayerListWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        manager.updateAppWidget(ids, PrayerListPainter.paint(context))
    }
}
