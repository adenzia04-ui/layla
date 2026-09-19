package com.adenzia.layla

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * What somebody meets when they open a paused app during a prayer window.
 *
 * This is the Android answer to Apple's Screen Time shield, and it is worth
 * being clear about the difference. Apple's screen is drawn by the operating
 * system: the blocked app never runs and has no way to interfere. This one is
 * an Activity of ours, launched over the top a fraction of a second after the
 * other app appears. The other app is briefly visible, and a determined
 * person can always leave. It is a nudge with the weight of a shield, not a
 * shield.
 *
 * Drawn in code rather than XML so it cannot drift from the app's own
 * palette, and so there is no layout inflation on a cold start — this runs
 * from a foreground service on a phone that may have been asleep, and every
 * millisecond before it covers Instagram is a millisecond of Instagram.
 */
class PrayerShieldActivity : Activity() {

    companion object {
        const val EXTRA_LABEL = "prayerLabel"
        const val EXTRA_ENDS_AT = "endsAtMillis"

        private val NAVY = Color.rgb(11, 27, 52)
        private val DEEP = Color.rgb(6, 13, 27)
        private val GOLD = Color.rgb(217, 178, 106)
        private val CREAM = Color.rgb(246, 241, 231)
        private val MIST = Color.rgb(150, 165, 190)

        fun intent(context: Context, label: String, endsAt: Long): Intent =
            Intent(context, PrayerShieldActivity::class.java)
                .putExtra(EXTRA_LABEL, label)
                .putExtra(EXTRA_ENDS_AT, endsAt)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TASK or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION,
                )
    }

    private var endsAt = 0L
    private lateinit var remaining: TextView
    private val handler = Handler(Looper.getMainLooper())

    private val tick = object : Runnable {
        override fun run() {
            val left = endsAt - System.currentTimeMillis()
            if (left <= 0) {
                finish()
                return
            }
            remaining.text = phrase(left)
            handler.postDelayed(this, 1_000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        val label = intent.getStringExtra(EXTRA_LABEL) ?: "Prayer"
        endsAt = intent.getLongExtra(EXTRA_ENDS_AT, 0L)
        setContentView(build(label))
        handler.post(tick)
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        // Re-raised for the same window while already showing. Keep the
        // countdown honest rather than starting a second one.
        intent?.let {
            endsAt = it.getLongExtra(EXTRA_ENDS_AT, endsAt)
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        super.onDestroy()
    }

    /**
     * Back does nothing.
     *
     * Not to trap anybody — the buttons below all leave — but because Back
     * from here would drop the person straight into the app the shield just
     * covered, which is the one outcome this screen exists to prevent. Home
     * still works, as it always must.
     */
    @Deprecated("Back is deliberately inert on the shield")
    override fun onBackPressed() {
        // Intentionally empty.
    }

    private fun build(label: String): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(NAVY, DEEP),
            )
            val pad = dp(28)
            setPadding(pad, pad, pad, pad)
        }

        root.addView(
            ImageView(this).apply {
                setImageResource(R.mipmap.ic_launcher_foreground)
            },
            LinearLayout.LayoutParams(dp(96), dp(96)),
        )

        root.addView(space(dp(16)))
        root.addView(
            text(label, 30f, CREAM, Typeface.BOLD, Gravity.CENTER),
        )
        root.addView(space(dp(6)))
        root.addView(
            text(
                "Prayer focus is on. This app is paused until you have prayed.",
                15f,
                MIST,
                Typeface.NORMAL,
                Gravity.CENTER,
            ),
        )

        root.addView(space(dp(22)))
        remaining = text("", 15f, GOLD, Typeface.NORMAL, Gravity.CENTER)
        root.addView(remaining)

        root.addView(space(dp(34)))
        root.addView(
            primary("I am praying now") {
                startActivity(
                    Intent(this, MainActivity::class.java)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                finish()
            },
        )
        root.addView(space(dp(10)))
        root.addView(
            quiet("I missed this prayer") {
                // Releases the lock for this window only. The streak is
                // decided by the confirmation inside the app, never here —
                // this button ends a block, it does not record a prayer.
                startService(
                    Intent(this, PrayerLockService::class.java)
                        .setAction(PrayerLockService.ACTION_STOP),
                )
                finish()
            },
        )
        root.addView(space(dp(4)))
        root.addView(
            quiet("Close") {
                startActivity(
                    Intent(Intent.ACTION_MAIN)
                        .addCategory(Intent.CATEGORY_HOME)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                finish()
            },
        )
        return root
    }

    /** "28 minutes left", and "less than a minute" rather than "0 minutes". */
    private fun phrase(msLeft: Long): String {
        val minutes = (msLeft / 60_000L).toInt()
        return when {
            minutes >= 2 -> "$minutes minutes left"
            minutes == 1 -> "1 minute left"
            else -> "Less than a minute left"
        }
    }

    private fun text(
        value: String,
        sizeSp: Float,
        colour: Int,
        style: Int,
        gravityFlag: Int,
    ) = TextView(this).apply {
        text = value
        setTextColor(colour)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
        setTypeface(typeface, style)
        gravity = gravityFlag
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        )
    }

    private fun primary(label: String, onTap: () -> Unit) = Button(this).apply {
        text = label
        isAllCaps = false
        setTextColor(DEEP)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
        background = GradientDrawable().apply {
            setColor(GOLD)
            cornerRadius = dp(28).toFloat()
        }
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(54),
        )
        setOnClickListener { onTap() }
    }

    private fun quiet(label: String, onTap: () -> Unit) = Button(this).apply {
        text = label
        isAllCaps = false
        setTextColor(MIST)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
        background = null
        layoutParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(46),
        )
        setOnClickListener { onTap() }
    }

    private fun space(height: Int) = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(1, height)
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
