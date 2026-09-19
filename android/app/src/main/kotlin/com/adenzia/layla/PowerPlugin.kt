package com.adenzia.layla

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Whether Android will let the reminders arrive.
 *
 * An exact alarm is booked for every prayer and the phone is free to ignore
 * it. Stock Android mostly does not; Samsung's One UI puts apps to sleep by
 * default and is the reason a prayer reminder arrives an hour late or never,
 * which for this app is the whole product failing silently — the alarm is
 * booked, the code is right, and nothing happens.
 *
 * iOS has no equivalent problem, which is why nothing here existed: a
 * scheduled local notification on an iPhone simply arrives.
 *
 * This only reads the state and opens the settings screen. It deliberately
 * does not hold `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, which would allow a
 * one-tap dialog: that permission is one Google restricts and reviews, and
 * this app already asks for exact alarms, usage access and an overlay. One
 * more sensitive permission to save one tap is a bad trade at review time.
 */
object PowerPlugin {

    private const val CHANNEL = "com.adenzia.layla/power"

    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handle(activity, call, result) }
    }

    private fun handle(
        activity: Activity,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            /** True when Android has agreed to leave the app alone. */
            "unrestricted" -> {
                val power = activity.getSystemService(Activity.POWER_SERVICE)
                    as? PowerManager
                result.success(
                    power?.isIgnoringBatteryOptimizations(activity.packageName)
                        ?: false,
                )
            }

            "openBatterySettings" -> {
                result.success(open(activity))
            }

            else -> result.notImplemented()
        }
    }

    /**
     * The list of apps and their battery setting, or the app's own page.
     *
     * The list is the screen that actually holds the switch. Some builds do
     * not have it, so the app's own settings page is the fallback — Battery
     * is one tap down from there on every Android I know of, including
     * Samsung's.
     */
    private fun open(activity: Activity): Boolean {
        val list = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (list.resolveActivity(activity.packageManager) != null) {
            activity.startActivity(list)
            return true
        }
        val details = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:${activity.packageName}"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (details.resolveActivity(activity.packageManager) != null) {
            activity.startActivity(details)
            return true
        }
        return false
    }
}
