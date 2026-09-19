package com.adenzia.layla

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.widget.RemoteViews
import kotlin.math.roundToInt

/**
 * Which way the Kaaba is, from the position the app last recorded.
 *
 * Deliberately not a live compass, exactly as on iOS: a widget has no
 * magnetometer and is redrawn on the system's schedule, so a needle claiming
 * to know which way you are *facing* would quietly lie between redraws. This
 * is the bearing from north, which does not change while you stand still.
 * Tapping opens the real compass.
 */
private object QiblaPainter {

    /**
     * The dial ships through Binder on every update, so it is kept to the
     * smallest square that still looks drawn rather than pixelated on a
     * three-times-density screen at about 60dp.
     */
    private const val DIAL_PX = 200
    private const val RING_STROKE_PX = 3f

    /**
     * The compass, in the shape the router can actually read.
     *
     * The iPhone widget taps to `layla://qibla`, and the obvious translation
     * of that is wrong here. Parsed, `layla://qibla` has host `qibla` and no
     * path at all, and go_router folds an empty path onto the splash route
     * before any redirect sees it — the same fold that `layla://add?code=`
     * only survives because its query still gives it away (see
     * lib/core/routing/invite_link.dart). With nothing to give it away, the
     * tap opened the app on Home while this widget's own hint said "Tap to
     * align".
     *
     * Three slashes instead of two: an empty host and a real path, which
     * go_router matches straight to `Routes.qibla`. The manifest's
     * intent-filter names only the scheme, so it matches either shape.
     * Checked with:
     *   adb shell am start -a android.intent.action.VIEW -d 'layla:///home/qibla'
     */
    private const val DEEP_LINK = "layla:///home/qibla"

    fun paint(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_qibla)
        val snapshot = Chrome.snapshot(context)
        val palette = Chrome.palette(context)

        Chrome.ground(views, R.id.widget_root, palette)
        views.setTextColor(R.id.qibla_label, palette.gold)
        views.setTextColor(R.id.qibla_bearing, palette.cream)
        views.setTextColor(R.id.qibla_hint, palette.mistFaint)
        Chrome.tap(context, views, R.id.widget_root, DEEP_LINK)

        if (snapshot == null) {
            views.setTextViewText(R.id.qibla_label, "Layla Pro")
            views.setImageViewBitmap(R.id.qibla_dial, dial(palette, null))
            views.setTextViewText(R.id.qibla_bearing, "Open the app")
            views.setTextViewText(R.id.qibla_hint, "to find the qibla")
            return views
        }

        val stale = snapshot.isStale(Chrome.nowSeconds())
        val located = Chrome.hasPosition(snapshot)

        // A day-old position is not a day-old prayer time, which is merely
        // the wrong hour: it is the wrong city if the person travelled, and
        // a needle drawn from it points confidently at nothing. Both the
        // unknown and the out-of-date case get the dial without a needle.
        val bearing = if (located && !stale) {
            Chrome.qiblaBearing(snapshot.latitude, snapshot.longitude)
        } else {
            null
        }

        views.setTextViewText(R.id.qibla_label, if (stale) "Out of date" else "Qibla")
        views.setImageViewBitmap(R.id.qibla_dial, dial(palette, bearing))
        views.setTextViewText(
            R.id.qibla_bearing,
            if (bearing == null) {
                "—"
            } else {
                // 359.7 rounds to 360, which is north said the long way.
                "${bearing.roundToInt() % 360}° from north"
            },
        )
        views.setTextViewText(
            R.id.qibla_hint,
            // Short on purpose. This line is 11sp in a cell that can be
            // dragged down to about 86dp of content, so a sentence is cut
            // off rather than read; the layout ellipsizes now, but "Open
            // Layla Pro to r…" is still not a thing to tell anybody.
            when {
                stale -> "Open Layla Pro"
                !located -> "Location needed"
                else -> "Tap to align"
            },
        )
        return views
    }

    /**
     * The whole instrument as one bitmap: the circle from [Chrome.ring] with
     * nothing lit, four ticks, and the needle if there is a bearing to draw.
     *
     * The proportions are the iPhone's, kept as fractions of the radius so
     * the two phones draw the same dial at different sizes.
     */
    private fun dial(palette: Palette, bearing: Double?): Bitmap {
        val bitmap = Chrome.ring(
            sizePx = DIAL_PX,
            strokePx = RING_STROKE_PX,
            fraction = 0f,
            trackColor = palette.mistFaint,
            litColor = palette.gold,
        )
        val canvas = Canvas(bitmap)
        val center = DIAL_PX / 2f
        val radius = center - RING_STROKE_PX / 2f

        val tick = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = radius * 0.05f
            strokeCap = Paint.Cap.ROUND
        }
        // The other three quarters exist only so north has something to be
        // north of, so north is the lit, longer one.
        for (quarter in 0 until 4) {
            val north = quarter == 0
            val length = if (north) radius * 0.18f else radius * 0.11f
            val outer = radius * 0.94f
            tick.color = if (north) palette.gold else palette.mistFaint
            canvas.save()
            canvas.rotate(quarter * 90f, center, center)
            canvas.drawLine(center, center - outer, center, center - outer + length, tick)
            canvas.restore()
        }

        if (bearing != null) {
            val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.FILL
                color = palette.gold
                // Software canvas, so a shadow layer is honoured on a shape
                // rather than silently dropped as it would be on the GPU.
                setShadowLayer(
                    radius * 0.07f,
                    0f,
                    0f,
                    (0x99 shl 24) or (palette.gold and 0x00FFFFFF),
                )
            }
            canvas.save()
            canvas.rotate(bearing.toFloat(), center, center)
            canvas.drawPath(needle(center, radius), glow)
            canvas.restore()
        }
        return bitmap
    }

    /**
     * The arrowhead, pointing up before it is rotated: apex, two tails, and a
     * notch between them, which is what makes it read as a needle rather than
     * a triangle.
     */
    private fun needle(center: Float, radius: Float): Path {
        val height = radius * 0.62f
        val halfWidth = height * 0.33f
        val tail = center + height / 2f
        return Path().apply {
            moveTo(center, center - height / 2f)
            lineTo(center + halfWidth, tail)
            lineTo(center, center + height * 0.16f)
            lineTo(center - halfWidth, tail)
            close()
        }
    }
}

class QiblaWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        manager.updateAppWidget(ids, QiblaPainter.paint(context))
    }
}
