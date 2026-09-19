package com.adenzia.layla

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.net.Uri
import android.os.SystemClock
import android.text.format.DateFormat
import android.widget.RemoteViews
import java.util.Date
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

/**
 * The parts every Layla Pro widget needs and none of them should own.
 *
 * There are eleven widgets on the home screen now. Nine of them were written
 * at once, and the fastest way to end up with nine subtly different phones is
 * for each to grow its own idea of what "the accent colour" or "a tap" means.
 * Everything shared lives here: the colours, the clock, the countdown, the
 * tap, and the two shapes RemoteViews cannot draw for itself.
 */
internal object Chrome {

    /** Kaaba, to five decimal places. */
    private const val KAABA_LAT = 21.4225
    private const val KAABA_LNG = 39.8262

    fun palette(context: Context): Palette =
        WidgetPalettes.named(WidgetStore.read(context)?.theme)

    fun snapshot(context: Context): WidgetStore.Snapshot? = WidgetStore.read(context)

    fun nowSeconds(): Long = System.currentTimeMillis() / 1000

    /** The set's ground, under everything. */
    fun ground(views: RemoteViews, rootId: Int, palette: Palette) {
        views.setInt(rootId, "setBackgroundResource", palette.background)
    }

    /**
     * The person's own 12- or 24-hour preference, not ours. Empty for a time
     * we were never given, rather than 1 January 1970.
     */
    fun clock(context: Context, seconds: Long): String =
        if (seconds <= 0) {
            ""
        } else {
            DateFormat.getTimeFormat(context).format(Date(seconds * 1000))
        }

    /**
     * Points a Chronometer at the moment something begins and lets the system
     * count down to it.
     *
     * A widget cannot redraw every second — the system will not allow it, and
     * a process woken sixty times a minute is a battery complaint — but a
     * Chronometer counts down on its own once it has been told when to stop.
     * The base has to be in `elapsedRealtime`, so it is the *difference* that
     * is carried across rather than the absolute time.
     */
    fun countdown(views: RemoteViews, id: Int, atSeconds: Long, hide: Boolean = false) {
        if (hide || atSeconds <= 0) {
            hideCountdown(views, id)
            return
        }
        val deltaMs = atSeconds * 1000 - System.currentTimeMillis()
        views.setChronometer(id, SystemClock.elapsedRealtime() + deltaMs, null, true)
        views.setChronometerCountDown(id, true)
    }

    /**
     * Stops a Chronometer and empties it.
     *
     * Stopping alone is not enough, and getting it wrong is visible: a
     * Chronometer with a base of zero reads as the time since the phone last
     * booted, so an empty widget once showed "42:27:13" and counted *up*,
     * which looks like a countdown to a prayer two days away.
     */
    fun hideCountdown(views: RemoteViews, id: Int) {
        views.setChronometer(id, 0, null, false)
        views.setChronometerCountDown(id, false)
        views.setTextViewText(id, "")
    }

    /**
     * Makes part of a widget open the app, optionally at a particular screen.
     *
     * `deepLink` is a `layla://` URL — the same ones the iPhone widgets use,
     * and the same ones the website's invite page falls back to. Passing null
     * simply opens the app where it was.
     *
     * The request code is derived from the link because PendingIntents that
     * differ only in their data are considered the same intent: without it,
     * three doors on the duas widget would all open whichever one was built
     * first.
     */
    fun tap(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        deepLink: String? = null,
    ) {
        val intent = if (deepLink == null) {
            Intent(context, MainActivity::class.java)
        } else {
            Intent(Intent.ACTION_VIEW, Uri.parse(deepLink))
                .setClass(context, MainActivity::class.java)
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        views.setOnClickPendingIntent(
            viewId,
            PendingIntent.getActivity(
                context,
                deepLink?.hashCode() ?: 0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            ),
        )
    }

    /**
     * The bearing to the Kaaba from where the app last was, in degrees
     * clockwise from true north.
     *
     * The great-circle initial bearing, not the direction on a flat map: at
     * this distance the two differ by enough to point at the wrong country.
     * Deliberately computed here from the stored position rather than read
     * live — a widget has no magnetometer, so a needle that claimed to know
     * which way you are *facing* would be lying. This says which way the
     * Kaaba is from here, which does not change while you stand still.
     */
    fun qiblaBearing(latitude: Double, longitude: Double): Double {
        val lat = Math.toRadians(latitude)
        val kaabaLat = Math.toRadians(KAABA_LAT)
        val dLng = Math.toRadians(KAABA_LNG - longitude)
        val y = sin(dLng) * cos(kaabaLat)
        val x = cos(lat) * sin(kaabaLat) - sin(lat) * cos(kaabaLat) * cos(dLng)
        return (Math.toDegrees(atan2(y, x)) + 360.0) % 360.0
    }

    /** Whether a position is one the app actually recorded. */
    fun hasPosition(snapshot: WidgetStore.Snapshot?): Boolean =
        snapshot != null && (snapshot.latitude != 0.0 || snapshot.longitude != 0.0)

    // MARK: - The two shapes RemoteViews cannot draw

    /**
     * A ring, part of it lit.
     *
     * RemoteViews can set a background drawable and it can set an image, and
     * that is all — there is no path, no arc, no stroke. Anything curved has
     * to arrive as a bitmap, drawn here and pushed across with
     * `setImageViewBitmap`. Kept small on purpose: every widget update ships
     * this bitmap through Binder, which has a hard transaction ceiling.
     */
    fun ring(
        sizePx: Int,
        strokePx: Float,
        fraction: Float,
        trackColor: Int,
        litColor: Int,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val inset = strokePx / 2f
        val box = RectF(inset, inset, sizePx - inset, sizePx - inset)

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = strokePx
            strokeCap = Paint.Cap.ROUND
        }

        paint.color = trackColor
        canvas.drawArc(box, 0f, 360f, false, paint)

        val swept = fraction.coerceIn(0f, 1f) * 360f
        if (swept > 0f) {
            paint.color = litColor
            canvas.drawArc(box, -90f, swept, false, paint)
        }
        return bitmap
    }

    /**
     * The open gauge from the app's own prayer card: an arc of a little over
     * half a turn, filled to `fraction`, with a bead at the head of the fill.
     */
    fun arc(
        widthPx: Int,
        heightPx: Int,
        strokePx: Float,
        fraction: Float,
        trackColor: Int,
        litColor: Int,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val inset = strokePx / 2f + 2f
        val box = RectF(inset, inset, widthPx - inset, heightPx * 2f - inset)

        val start = 180f
        val sweep = 180f

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = strokePx
            strokeCap = Paint.Cap.ROUND
        }

        paint.color = trackColor
        canvas.drawArc(box, start, sweep, false, paint)

        val done = fraction.coerceIn(0f, 1f)
        if (done > 0f) {
            paint.color = litColor
            canvas.drawArc(box, start, sweep * done, false, paint)

            // The bead. Without it the gauge reads as "some amount" rather
            // than "here"; with it the eye lands on the position.
            val angle = Math.toRadians((start + sweep * done).toDouble())
            val cx = box.centerX() + (box.width() / 2f) * cos(angle).toFloat()
            val cy = box.centerY() + (box.height() / 2f) * sin(angle).toFloat()
            canvas.drawCircle(
                cx,
                cy,
                strokePx * 0.75f,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = litColor },
            )
        }
        return bitmap
    }
}
