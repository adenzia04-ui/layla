package com.adenzia.layla

import android.app.Activity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Android end of the widget channel.
 *
 * Answers the same channel iOS does, so the Dart side has one bridge rather
 * than two. Everything it cannot do returns quietly rather than failing:
 * there is no Live Activity on Android and no globe in these widgets, and a
 * call for either should not look like an error.
 */
object WidgetPlugin {

    private const val CHANNEL = "com.noorapp.noor/widgets"

    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                handle(activity, call, result)
            }
    }

    private fun handle(
        activity: Activity,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "publishSnapshot" -> {
                // A JSON string, not a map. WidgetSnapshot.toJson encodes
                // before it crosses, because that is the shape iOS wants —
                // asking for a Map here threw ClassCastException on every
                // single publish, and the Dart side swallows a failed
                // invoke, so the widgets simply never received anything and
                // sat in their empty state for good.
                val snapshot = call.argument<String>("snapshot")
                if (snapshot.isNullOrEmpty()) {
                    result.success(false)
                    return
                }
                WidgetStore.write(activity, snapshot)
                PrayerWidgets.refreshAll(activity)
                result.success(true)
            }

            "reloadWidgets" -> {
                PrayerWidgets.refreshAll(activity)
                result.success(true)
            }

            // The `layla://` url this launch began with, if a widget tap
            // began it. See MainActivity.launchLink for why Flutter's own
            // deep linking cannot answer this one.
            "consumeLaunchLink" -> result.success(
                (activity as? MainActivity)?.consumeLaunchLink(),
            )

            // iOS-only, and silence is the honest answer. The Dart side
            // already treats a missing implementation as "not here"; these
            // exist so a call does not read as a failure in the log.
            "publishGlobe",
            "startLiveActivity",
            "updateLiveActivity",
            "endLiveActivity",
            -> result.success(false)

            "liveActivitiesEnabled" -> result.success(false)

            else -> result.notImplemented()
        }
    }
}
