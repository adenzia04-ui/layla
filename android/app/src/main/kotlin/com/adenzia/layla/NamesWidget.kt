package com.adenzia.layla

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews

/**
 * One of the ninety-nine, with its number, transliteration and meaning.
 *
 * The list and the rotation both live in `WidgetNames.kt`, which is generated
 * from `ios/NoorWidgets/NamesWidget.swift` and mirrors the Soul tab, so the
 * two phones and the app never disagree about today's name.
 *
 * The only widget here that needs nothing from the app: the name follows from
 * the date alone, so it is right even on a phone where Layla Pro has never
 * been opened. The snapshot is consulted for one thing, the colour set.
 */
private object NamesPainter {

    fun paint(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_names)
        val palette = Chrome.palette(context)
        val (name, number) = DivineNames.forDay()

        Chrome.ground(views, R.id.widget_root, palette)
        views.setTextColor(R.id.names_title, palette.gold)
        views.setTextColor(R.id.names_count, palette.gold)
        views.setTextColor(R.id.names_arabic, palette.gold)
        views.setTextColor(R.id.names_arabic_long, palette.gold)
        views.setTextColor(R.id.names_translit, palette.cream)
        views.setTextColor(R.id.names_meaning, palette.mist)
        views.setTextColor(R.id.names_note, palette.mistFaint)

        views.setTextViewText(R.id.names_title, "Name of Allah")
        views.setTextViewText(
            R.id.names_count,
            "$number of ${DivineNames.all.size}",
        )

        // iOS shrinks this line until it fits. RemoteViews has no setter for
        // text size, so both sizes sit in the layout and one is hidden. The
        // two names made of more than one word are also the only two wide
        // enough to need the smaller of them — every other name is a single
        // word no more than eight letters long.
        val wide = name.arabic.contains(' ')
        val shown = if (wide) R.id.names_arabic_long else R.id.names_arabic
        val hidden = if (wide) R.id.names_arabic else R.id.names_arabic_long
        views.setTextViewText(shown, name.arabic)
        views.setViewVisibility(shown, View.VISIBLE)
        views.setViewVisibility(hidden, View.GONE)

        views.setTextViewText(R.id.names_translit, name.transliteration)
        views.setTextViewText(R.id.names_meaning, name.meaning)

        // Nothing drawn above came out of the snapshot, so a stale one cannot
        // make this widget wrong and it would be a lie to say it is out of
        // date. A missing one means only that no colour set has been chosen
        // and this is Midnight rather than the person's own — worth saying
        // quietly, because otherwise the widget looks like it ignored them.
        val unclaimed = Chrome.snapshot(context) == null
        views.setTextViewText(
            R.id.names_note,
            if (unclaimed) "Open Layla Pro to choose the colours" else "",
        )
        views.setViewVisibility(
            R.id.names_note,
            if (unclaimed) View.VISIBLE else View.GONE,
        )

        Chrome.tap(context, views, R.id.widget_root, "layla://names")
        return views
    }
}

class NamesWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        manager.updateAppWidget(ids, NamesPainter.paint(context))
    }
}
