package com.adenzia.layla

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    /**
     * The `layla://` url the app was launched with, if it was.
     *
     * Flutter's own deep linking does not deliver a scheme-only url on a cold
     * start. `layla://qibla` has no path, and by the time the router's first
     * redirect runs the uri it is given is plain `/` — the destination has
     * already been dropped. Tapping a widget with the app closed therefore
     * opened the home screen, while tapping the same widget with the app
     * already running went to the right place, which is a difference nobody
     * would report as a bug and everybody would feel as one.
     *
     * The intent still has it, so it is kept here and handed over once, the
     * first time Dart asks.
     */
    private var launchLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        launchLink = laylaLink(intent)
        PrayerLockPlugin.register(this, flutterEngine)
        WidgetPlugin.register(this, flutterEngine)
        MatVisionPlugin.register(this, flutterEngine)
        PowerPlugin.register(this, flutterEngine)
    }

    /**
     * The app was already running. Flutter's deep linking handles this case
     * correctly, so the link is not kept — keeping it would mean navigating
     * twice for one tap.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    /** Hands the launch link over, once. */
    fun consumeLaunchLink(): String? {
        val link = launchLink
        launchLink = null
        return link
    }

    private fun laylaLink(intent: Intent?): String? {
        val data = intent?.dataString ?: return null
        return if (data.startsWith("layla://")) data else null
    }
}
