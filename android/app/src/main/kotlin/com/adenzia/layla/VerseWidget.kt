package com.adenzia.layla

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar

/**
 * The verse of the day, as the iPhone has drawn it since the start.
 *
 * The one widget here that owes nothing to the snapshot. Which verse is
 * showing is arithmetic on the clock — see `Verses.forDay` — so this is
 * still true on a phone where the app has never been opened, and still true
 * when the stored day is yesterday's. The snapshot is read for one thing
 * only: which of the nine colour sets the person chose.
 */
private object VersePainter {

    /**
     * Above this many letters the verse moves to the smaller of the two
     * Arabic views. Counted without the harakat, which sit above and below
     * the letters and take no width of their own — counting them would put
     * every heavily-marked short verse into the small size for nothing.
     */
    private const val LONG_VERSE = 44

    fun paint(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_verse)

        // Read once rather than through Chrome.palette, which would parse the
        // stored JSON a second time for the theme alone.
        val snapshot = Chrome.snapshot(context)
        val palette = WidgetPalettes.named(snapshot?.theme)
        val verse = Verses.forDay()

        Chrome.ground(views, R.id.widget_root, palette)
        views.setTextColor(R.id.verse_header, palette.gold)
        views.setTextColor(R.id.verse_arabic, palette.gold)
        views.setTextColor(R.id.verse_arabic_long, palette.gold)
        views.setTextColor(R.id.verse_english, palette.cream)
        views.setTextColor(R.id.verse_reference, palette.gold)
        views.setTextColor(R.id.verse_hint, palette.mistFaint)

        views.setTextViewText(R.id.verse_header, "Verse of the day")
        views.setTextViewText(R.id.verse_english, verse.english)
        views.setTextViewText(R.id.verse_reference, verse.reference)

        // Both Arabic views are written and one is hidden, the same way the
        // names widget picks between its two sizes. Writing only the visible
        // one would leave yesterday's long verse sitting in the hidden view,
        // which shows through the moment a later draw swaps the sizes over.
        val long = letters(verse.arabic) > LONG_VERSE
        val shown = if (long) R.id.verse_arabic_long else R.id.verse_arabic
        val hidden = if (long) R.id.verse_arabic else R.id.verse_arabic_long
        views.setTextViewText(shown, verse.arabic)
        views.setViewVisibility(shown, View.VISIBLE)
        views.setTextViewText(hidden, "")
        views.setViewVisibility(hidden, View.GONE)

        // Nothing above this line is wrong when there is no snapshot, so the
        // widget is not blanked and no "open the app" is put where the verse
        // belongs. The colours are the only thing missing, and the line says
        // so instead of pretending Midnight was a choice.
        if (snapshot == null) {
            views.setTextViewText(
                R.id.verse_hint,
                "Open Layla Pro to choose its colours",
            )
            views.setViewVisibility(R.id.verse_hint, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.verse_hint, View.GONE)
        }

        Chrome.tap(context, views, R.id.widget_root, "layla://verse")
        return views
    }

    /** Letters that take width: everything but the combining marks. */
    private fun letters(arabic: String): Int =
        arabic.count { it.category != CharCategory.NON_SPACING_MARK }
}

/**
 * The twelve-hour turnover.
 *
 * `updatePeriodMillis` is 0 here as on every other Layla Pro widget, and the
 * app pushes a redraw whenever it publishes a snapshot — that is what carries
 * a change of colour set across. But this widget claims something none of the
 * others do: that the verse changes twice a day. A push only happens when the
 * app is opened, so on a phone left alone the widget sat on whichever verse
 * was current when it was placed and quietly contradicted its own premise.
 *
 * So it books its own redraw for the next noon or midnight. One alarm, two
 * firings a day, re-armed on every draw. Deliberately *not*
 * `updatePeriodMillis`: the floor is thirty minutes, which would be
 * forty-eight wakeups a day — and each one wakes the device — to catch a
 * boundary that passes twice.
 */
private object VerseRollover {

    private const val REQUEST = 0x5645

    fun arm(context: Context) {
        val manager = AppWidgetManager.getInstance(context) ?: return
        val ids = manager.getAppWidgetIds(ComponentName(context, VerseWidget::class.java))
        if (ids == null || ids.isEmpty()) return

        val alarms = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return
        val intent = pending(context, ids, create = true) ?: return
        try {
            // RTC rather than RTC_WAKEUP on purpose. Nobody is reading a
            // widget on a dark screen, so there is nothing to be gained by
            // waking the phone at midnight; the alarm is delivered the next
            // time it is awake, which is the moment before the person looks.
            alarms.set(AlarmManager.RTC, nextBoundary(), intent)
        } catch (_: Exception) {
            // An alarm this widget could not book is a verse that turns over
            // late, not a widget that fails to draw. Never let it take the
            // draw down with it.
        }
    }

    fun disarm(context: Context) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val intent = pending(context, IntArray(0), create = false) ?: return
        alarms?.cancel(intent)
        intent.cancel()
    }

    /**
     * The ids have to travel with the intent: `AppWidgetProvider.onReceive`
     * drops an APPWIDGET_UPDATE that carries no EXTRA_APPWIDGET_IDS without
     * ever calling `onUpdate`, so an alarm sent without them would fire on
     * time and redraw nothing. They are re-read on every arm rather than
     * remembered, so a second widget added later is covered by the next draw.
     */
    private fun pending(context: Context, ids: IntArray, create: Boolean): PendingIntent? {
        val intent = Intent(context, VerseWidget::class.java)
            .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        // FLAG_NO_CREATE on the way out, so cancelling looks the alarm up
        // rather than booking a fresh one only to throw it away.
        val mode = if (create) {
            PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_NO_CREATE
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST,
            intent,
            PendingIntent.FLAG_IMMUTABLE or mode,
        )
    }

    /**
     * The next local noon or midnight, which is where `Verses.forDay` changes
     * its answer — it reads HOUR_OF_DAY in the phone's own zone, so this has
     * to be computed in that zone too and not off a UTC millisecond count.
     *
     * A couple of seconds past the boundary rather than on it: an alarm that
     * lands a moment early would redraw the verse that is on its way out.
     */
    private fun nextBoundary(now: Long = System.currentTimeMillis()): Long {
        val cal = Calendar.getInstance()
        cal.timeInMillis = now
        val afternoon = cal.get(Calendar.HOUR_OF_DAY) >= 12
        cal.set(Calendar.HOUR_OF_DAY, if (afternoon) 0 else 12)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 2)
        cal.set(Calendar.MILLISECOND, 0)
        // Setting midnight lands on this morning's, which is already behind
        // us; the same add covers a noon that has just gone by.
        if (cal.timeInMillis <= now) cal.add(Calendar.DAY_OF_MONTH, 1)
        return cal.timeInMillis
    }
}

class VerseWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        manager.updateAppWidget(ids, VersePainter.paint(context))
        // Re-armed on every draw, so the alarm heals itself: the app pushing
        // a snapshot, the launcher rebinding, or the previous rollover all
        // book the next one.
        VerseRollover.arm(context)
    }

    /** The last one has been taken off the home screen; stop the alarm. */
    override fun onDisabled(context: Context) {
        VerseRollover.disarm(context)
    }
}
