package com.adenzia.layla

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.text.format.DateFormat
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import java.util.Date

/**
 * The home-screen widgets, and the one place that draws them.
 *
 * iOS has had these since the start, on WidgetKit, and Android had none at
 * all — the settings screen that chooses their colours was hidden on Android
 * precisely because there was nothing to colour. These are the Android ones:
 * the next prayer with a live countdown, and the whole day with the next one
 * lit.
 *
 * The countdown is a `Chronometer` rather than text the app rewrites. A
 * widget cannot redraw every second — the system will not allow it, and a
 * process woken sixty times a minute would be a battery complaint — but a
 * Chronometer counts down on its own once it is told when to stop.
 */
private object WidgetPainter {

    fun paintNextPrayer(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_next_prayer)
        val snapshot = WidgetStore.read(context)
        val now = System.currentTimeMillis() / 1000

        if (snapshot == null) {
            views.setTextViewText(R.id.next_label, "Layla Pro")
            views.setTextViewText(R.id.next_name, "Open the app")
            views.setTextViewText(R.id.next_time, "to see today's prayers")
            hideCountdown(views)
            openApp(context, views)
            return views
        }

        val stale = snapshot.isStale(now)
        views.setTextViewText(
            R.id.next_label,
            if (stale) "Out of date" else "Next prayer",
        )
        views.setTextViewText(
            R.id.next_name,
            snapshot.prayers
                .firstOrNull { it.key == snapshot.nextKey }
                ?.label
                ?: "Prayer",
        )
        views.setTextViewText(
            R.id.next_time,
            if (stale) {
                "Open Layla Pro to refresh"
            } else {
                clock(context, snapshot.nextStartsAtSeconds)
            },
        )
        countdownTo(views, snapshot.nextStartsAtSeconds, hide = stale)
        openApp(context, views)
        return views
    }

    fun paintPrayerTimes(
        context: Context,
        layout: Int = R.layout.widget_prayer_times,
    ): RemoteViews {
        val compact = layout == R.layout.widget_prayer_times_compact
        val views = RemoteViews(context.packageName, layout)
        val snapshot = WidgetStore.read(context)
        val now = System.currentTimeMillis() / 1000

        if (snapshot == null) {
            views.setTextViewText(R.id.header_today, "Layla Pro")
            views.setTextViewText(R.id.header_hijri, "Open the app")
            views.setTextViewText(R.id.header_city, "")
            views.setTextViewText(R.id.until_label, "")
            if (!compact) {
                views.setTextViewText(
                    R.id.footer,
                    "Today's prayers will appear here.",
                )
            }
            hideCountdown(views)
            openApp(context, views)
            return views
        }

        val stale = snapshot.isStale(now)
        val next = snapshot.prayers.firstOrNull { it.key == snapshot.nextKey }

        views.setTextViewText(R.id.header_today, if (stale) "Out of date" else "Today")
        views.setTextViewText(R.id.header_hijri, snapshot.hijri)
        views.setTextViewText(R.id.header_city, snapshot.city)
        views.setTextViewText(
            R.id.until_label,
            if (stale || next == null) "" else "Until ${next.label}",
        )
        countdownTo(views, snapshot.nextStartsAtSeconds, hide = stale)

        // Six cells: the five prayers plus sunrise, in the order the app sent
        // them. A slot the app did not fill is left blank rather than invented.
        val slots = if (compact) 3 else CELLS.size
        for (slot in 0 until slots) {
            val prayer = snapshot.prayers.getOrNull(slot)
            if (prayer == null) {
                // The app sends the five obligatory prayers, so the sixth
                // cell is usually empty. Drawn, it was a blank tile with a
                // background sitting next to real ones; gone, the row simply
                // ends where the prayers do.
                views.setViewVisibility(CELLS[slot], View.GONE)
                continue
            }
            views.setViewVisibility(CELLS[slot], View.VISIBLE)
            val isNext = prayer.key == snapshot.nextKey && !stale
            views.setTextViewText(NAMES[slot], prayer.label)
            views.setTextViewText(TIMES[slot], clock(context, prayer.startsAtSeconds))
            views.setTextColor(TIMES[slot], if (isNext) GOLD else CREAM)
            views.setInt(
                CELLS[slot],
                "setBackgroundResource",
                if (isNext) R.drawable.widget_cell_next else R.drawable.widget_cell,
            )
        }

        if (!compact) {
            views.setTextViewText(
                R.id.footer,
                if (stale) {
                    "These are not today's. Open Layla Pro to refresh."
                } else {
                    "${snapshot.completedToday} of ${snapshot.totalToday} " +
                        "confirmed today"
                },
            )
        }
        openApp(context, views)
        return views
    }

    private const val GOLD = 0xFFD9B26A.toInt()
    private const val CREAM = 0xFFF6F1E7.toInt()

    private val CELLS = intArrayOf(
        R.id.cell0, R.id.cell1, R.id.cell2,
        R.id.cell3, R.id.cell4, R.id.cell5,
    )
    private val NAMES = intArrayOf(
        R.id.p0_name, R.id.p1_name, R.id.p2_name,
        R.id.p3_name, R.id.p4_name, R.id.p5_name,
    )
    private val TIMES = intArrayOf(
        R.id.p0_time, R.id.p1_time, R.id.p2_time,
        R.id.p3_time, R.id.p4_time, R.id.p5_time,
    )

    /**
     * Stops the Chronometer and empties it.
     *
     * Stopping alone is not enough, and getting this wrong is visible: a
     * Chronometer with a base of zero reads as the time since the phone last
     * booted, so an empty widget was showing "42:27:13" and counting UP —
     * which looks like a countdown to a prayer two days away.
     */
    private fun hideCountdown(views: RemoteViews) {
        views.setChronometer(R.id.next_countdown, 0, null, false)
        views.setChronometerCountDown(R.id.next_countdown, false)
        views.setTextViewText(R.id.next_countdown, "")
    }

    /**
     * Points the Chronometer at the moment the prayer begins and lets the
     * system count down to it.
     *
     * The base has to be in `elapsedRealtime`, not wall-clock, so it is the
     * difference that is carried across rather than the absolute time.
     */
    private fun countdownTo(views: RemoteViews, atSeconds: Long, hide: Boolean) {
        if (hide || atSeconds <= 0) {
            hideCountdown(views)
            return
        }
        val deltaMs = atSeconds * 1000 - System.currentTimeMillis()
        views.setChronometer(
            R.id.next_countdown,
            SystemClock.elapsedRealtime() + deltaMs,
            null,
            true,
        )
        views.setChronometerCountDown(R.id.next_countdown, true)
    }

    /** The person's own 12- or 24-hour preference, not ours. */
    private fun clock(context: Context, seconds: Long): String =
        if (seconds <= 0) {
            ""
        } else {
            DateFormat.getTimeFormat(context).format(Date(seconds * 1000))
        }

    private fun openApp(context: Context, views: RemoteViews) {
        views.setOnClickPendingIntent(
            R.id.widget_root,
            PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            ),
        )
    }
}

/** Redraws every widget of both kinds. Called when the app has new times. */
object PrayerWidgets {
    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context) ?: return
        redraw(context, manager, NextPrayerWidget::class.java)
        redraw(context, manager, PrayerTimesWidget::class.java)
    }

    private fun redraw(
        context: Context,
        manager: AppWidgetManager,
        provider: Class<*>,
    ) {
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        if (ids == null || ids.isEmpty()) return
        val views = if (provider == NextPrayerWidget::class.java) {
            WidgetPainter.paintNextPrayer(context)
        } else {
            WidgetPainterResponsive(context)
        }
        manager.updateAppWidget(ids, views)
    }
}

/**
 * Two drawings of the wide widget, and the system picks.
 *
 * Android crops a widget that does not fit rather than scrolling it, so at
 * a short size the second row of prayers was cut in half and the footer was
 * lost. From Android 12 a widget can carry several layouts keyed by size and
 * the launcher chooses; below that there is only the full one, which is what
 * it always had.
 */
private fun WidgetPainterResponsive(context: Context): RemoteViews =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        RemoteViews(
            mapOf(
                SizeF(180f, 110f) to
                    WidgetPainter.paintPrayerTimes(
                        context,
                        R.layout.widget_prayer_times_compact,
                    ),
                SizeF(180f, 170f) to WidgetPainter.paintPrayerTimes(context),
            ),
        )
    } else {
        WidgetPainter.paintPrayerTimes(context)
    }

class NextPrayerWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        manager.updateAppWidget(ids, WidgetPainter.paintNextPrayer(context))
    }
}

class PrayerTimesWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        manager.updateAppWidget(ids, WidgetPainterResponsive(context))
    }
}
