package com.adenzia.layla

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        PrayerLockPlugin.register(this, flutterEngine)
        WidgetPlugin.register(this, flutterEngine)
    }
}
