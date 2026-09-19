package com.adenzia.layla

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The small widget that asks one thing: pray.
 *
 * Mirrors `ios/NoorWidgets/PrayWidget.swift`. The count is the app's to know
 * — a prayer counts once it is confirmed with a photo of the mat — so it is
 * only ever drawn from what the app wrote, and it shows a dash rather than a
 * hopeful zero when the app has not synced today. "0 of 5" and "we have no
 * idea" look identical otherwise, and the first is an accusation.
 */
private object PrayPainter {

    /**
     * Home — `Routes.home` in `lib/core/routing/routes.dart`, which is where
     * the prayer card and its confirm live.
     *
     * Three slashes, not two, for the reason `TasbihWidget` spells out: in
     * `layla://pray` the word after the slashes is the *host* and the path is
     * empty, and go_router folds a pathless link onto the splash route. The
     * button labelled Pray therefore sat through four and a half seconds of
     * splash animation and then landed wherever `SplashScreen` decided —
     * home, by accident rather than by the link, and the welcome screen for
     * anyone signed out. The empty authority in `layla:///…` leaves the whole
     * route in the path, which is what the Dart side matches on, and the
     * manifest's scheme-only intent filter accepts it either way.
     *
     * Not `layla://pray` as on the iPhone: there is no `/pray` route and
     * nothing in `app_router.dart` maps a widget's host to one. Either that
     * redirect grows a branch for the widget hosts, or `PrayWidget.swift`'s
     * `widgetURL` follows this one — both are somebody else's file.
     */
    private const val DEEP_LINK = "layla:///home"

    /** Ring bitmap. Small on purpose — every update ships it over Binder. */
    private const val RING_PX = 120
    private const val RING_STROKE_PX = 10f

    /** En dash, the same character the Swift draws. */
    private const val DASH = "–"

    fun paint(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_pray)
        val palette = Chrome.palette(context)
        val snapshot = Chrome.snapshot(context)

        Chrome.ground(views, R.id.widget_root, palette)
        views.setTextColor(R.id.pray_done, palette.gold)
        views.setTextColor(R.id.pray_total, palette.mist)
        views.setTextColor(R.id.pray_next, palette.cream)
        views.setTextColor(R.id.pray_time, palette.mist)
        views.setTextColor(R.id.pray_date, palette.mistFaint)
        views.setTextColor(R.id.pray_button, palette.gold)
        views.setInt(R.id.pray_button, "setBackgroundResource", palette.cellNext)

        if (snapshot == null) {
            drawRing(views, palette, done = null, total = 5)
            views.setTextViewText(R.id.pray_next, "Open the app")
            views.setTextViewText(R.id.pray_time, "to see today's prayers")
            views.setViewVisibility(R.id.pray_date, View.GONE)
            tap(context, views)
            return views
        }

        val stale = snapshot.isStale(Chrome.nowSeconds())
        val total = snapshot.totalToday.coerceAtLeast(1)
        drawRing(
            views,
            palette,
            done = if (stale) null else snapshot.completedToday,
            total = total,
        )

        if (stale) {
            // Yesterday's next prayer is not today's, so it is not shown at
            // all rather than shown with a caveat underneath it.
            views.setTextViewText(R.id.pray_next, "Out of date")
            views.setTextViewText(R.id.pray_time, "Open Layla Pro to refresh")
            views.setViewVisibility(R.id.pray_date, View.GONE)
            tap(context, views)
            return views
        }

        views.setTextViewText(
            R.id.pray_next,
            snapshot.prayers
                .firstOrNull { it.key == snapshot.nextKey }
                ?.label
                ?: "Prayer",
        )
        views.setTextViewText(
            R.id.pray_time,
            Chrome.clock(context, snapshot.nextStartsAtSeconds),
        )
        views.setViewVisibility(R.id.pray_date, View.VISIBLE)
        views.setTextViewText(
            R.id.pray_date,
            SimpleDateFormat("MM/dd", Locale.getDefault()).format(Date()),
        )
        tap(context, views)
        return views
    }

    /** A null `done` is "we were not told", and draws the dash and no fill. */
    private fun drawRing(
        views: RemoteViews,
        palette: Palette,
        done: Int?,
        total: Int,
    ) {
        views.setImageViewBitmap(
            R.id.pray_ring,
            Chrome.ring(
                RING_PX,
                RING_STROKE_PX,
                if (done == null) 0f else done.toFloat() / total.toFloat(),
                palette.mist,
                palette.gold,
            ),
        )
        views.setTextViewText(R.id.pray_done, done?.toString() ?: DASH)
        views.setTextViewText(R.id.pray_total, "/$total")
    }

    /**
     * The button carries its own intent as well as the root's: a TextView is
     * not clickable, so a tap on it would otherwise fall through to the root
     * — which works, but only by accident.
     */
    private fun tap(context: Context, views: RemoteViews) {
        Chrome.tap(context, views, R.id.widget_root, DEEP_LINK)
        Chrome.tap(context, views, R.id.pray_button, DEEP_LINK)
    }
}

class PrayWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        manager.updateAppWidget(ids, PrayPainter.paint(context))
    }
}
