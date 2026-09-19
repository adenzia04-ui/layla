package com.adenzia.layla

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.widget.RemoteViews

/**
 * The dua library, one tap from the home screen.
 *
 * Three doors rather than one, the same three the iPhone offers: "all of
 * them" is the least useful door when what someone actually wants at 6am is
 * the morning adhkar. The three labels are still the iPhone's; their three
 * destinations are not, yet — see DEEP_LINK. Every cell is a target and so is
 * the root, so a tap on the header or the gap between cells still lands
 * somewhere.
 *
 * Alone among the widgets this one reads nothing out of the snapshot but the
 * colour set, so it has no empty state and no stale state: the doors are as
 * true before the app has ever run as they are after.
 */
private object DuasPainter {

    private const val ICON_DP = 20f

    /**
     * The Soul hub — `Routes.tasbih` in `lib/core/routing/routes.dart` — which
     * is the screen the Duas entry sits on.
     *
     * Three slashes, not two, for the reason `TasbihWidget` spells out: in
     * `layla://duas` the word after the slashes is the *host* and the path is
     * empty, and go_router folds a pathless link onto the splash route. That
     * is what the third door and the root were doing — opening the app on the
     * splash animation and leaving it wherever `SplashScreen` decided.
     *
     * One link behind all three doors, which is not where this should end up.
     * `layla://duas/morning` and `layla://duas/praise` are the iPhone's own
     * links and they were copied across as they stand, but parsed they are
     * the paths `/morning` and `/praise`, which no route matches — so those
     * two doors reached go_router's not-found screen, which is worse than
     * landing a screen early. `DuaLibraryScreen` and `DuaCategoryScreen` do
     * exist; they are pushed with `Navigator.push` from inside the hub and
     * have no path of their own to link to. Give them routes in
     * `app_router.dart` and each door can have its own destination back;
     * until then all three share the nearest one that is real. Those are
     * somebody else's files, as is `ios/NoorWidgets/LauncherWidgets.swift`,
     * where the same three links have the same problem.
     */
    private const val DEEP_LINK = "layla:///tasbih"

    private enum class Glyph { SUNRISE, SPARKLE, BOOK }

    private class Door(
        val cellId: Int,
        val iconId: Int,
        val titleId: Int,
        val title: String,
        val glyph: Glyph,
    )

    private val DOORS = listOf(
        Door(
            R.id.door_morning, R.id.morning_icon, R.id.morning_title,
            "Morning &\nEvening", Glyph.SUNRISE,
        ),
        Door(
            R.id.door_praise, R.id.praise_icon, R.id.praise_title,
            "Praising\nAllah", Glyph.SPARKLE,
        ),
        Door(
            R.id.door_all, R.id.all_icon, R.id.all_title,
            "All\nDuas", Glyph.BOOK,
        ),
    )

    fun paint(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_duas)
        val palette = Chrome.palette(context)

        Chrome.ground(views, R.id.widget_root, palette)
        views.setTextViewText(R.id.header_title, "Duas")
        views.setTextColor(R.id.header_title, palette.gold)

        val iconPx = (ICON_DP * context.resources.displayMetrics.density)
            .toInt()
            .coerceAtLeast(1)

        for (door in DOORS) {
            views.setInt(door.cellId, "setBackgroundResource", palette.cell)
            views.setTextViewText(door.titleId, door.title)
            views.setTextColor(door.titleId, palette.cream)
            views.setImageViewBitmap(
                door.iconId,
                symbol(door.glyph, iconPx, palette.gold),
            )
            Chrome.tap(context, views, door.cellId, DEEP_LINK)
        }

        Chrome.tap(context, views, R.id.widget_root, DEEP_LINK)
        return views
    }

    /**
     * The three symbols, drawn at paint time rather than shipped as
     * drawables.
     *
     * A drawable would be stuck at one colour: none of the RemoteViews
     * setters that are safe here can tint an ImageView, and Sand is the set
     * that inverts — bone ground, dark brown accent — so a single gold asset
     * would sit on it as a bright smudge. Drawn, the symbol is whatever the
     * chosen set's accent is. They are kept to twenty points because every
     * one of them crosses Binder on each update.
     */
    private fun symbol(glyph: Glyph, sizePx: Int, tint: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val s = sizePx.toFloat()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = tint

        when (glyph) {
            // sun.horizon.fill — a disc standing clear of the horizon line.
            Glyph.SUNRISE -> {
                canvas.save()
                canvas.clipRect(0f, 0f, s, s * 0.70f)
                canvas.drawCircle(s * 0.50f, s * 0.70f, s * 0.26f, paint)
                canvas.restore()

                paint.style = Paint.Style.STROKE
                paint.strokeCap = Paint.Cap.ROUND
                paint.strokeWidth = s * 0.09f
                canvas.drawLine(s * 0.06f, s * 0.82f, s * 0.94f, s * 0.82f, paint)
                canvas.drawLine(s * 0.50f, s * 0.10f, s * 0.50f, s * 0.24f, paint)
                canvas.drawLine(s * 0.14f, s * 0.32f, s * 0.22f, s * 0.40f, paint)
                canvas.drawLine(s * 0.86f, s * 0.32f, s * 0.78f, s * 0.40f, paint)
            }

            // sparkles — the large star with its small companion.
            Glyph.SPARKLE -> {
                canvas.drawPath(star(s * 0.42f, s * 0.54f, s * 0.34f), paint)
                canvas.drawPath(star(s * 0.78f, s * 0.24f, s * 0.17f), paint)
            }

            // book.closed.fill — spine and cover, seen from the fore edge.
            Glyph.BOOK -> {
                val top = s * 0.12f
                val bottom = s * 0.88f
                canvas.drawRoundRect(
                    RectF(s * 0.18f, top, s * 0.30f, bottom),
                    s * 0.05f, s * 0.05f, paint,
                )
                canvas.drawRoundRect(
                    RectF(s * 0.36f, top, s * 0.84f, bottom),
                    s * 0.07f, s * 0.07f, paint,
                )
            }
        }
        return bitmap
    }

    /** A four-point star: four arms whose sides curve in to the centre. */
    private fun star(cx: Float, cy: Float, r: Float): Path = Path().apply {
        moveTo(cx, cy - r)
        quadTo(cx, cy, cx + r, cy)
        quadTo(cx, cy, cx, cy + r)
        quadTo(cx, cy, cx - r, cy)
        quadTo(cx, cy, cx, cy - r)
        close()
    }
}

/**
 * Redrawn along with the rest not because the doors ever change, but because
 * the colour set can.
 */
class DuasWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        manager.updateAppWidget(ids, DuasPainter.paint(context))
    }
}
