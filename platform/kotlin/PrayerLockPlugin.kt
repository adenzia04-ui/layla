package com.noorapp.noor

import android.app.Activity
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Dart's `PrayerLockPlatform` to the Android soft lock.
 *
 * Everything here is opt-in and reversible. Read
 * docs/PRAYER_LOCK_LIMITATIONS.md before extending it — in particular, do NOT
 * reach for an AccessibilityService: it would work, and it would also get the
 * app removed from Play.
 */
object PrayerLockPlugin {

    private const val CHANNEL = "com.noorapp.noor/prayer_lock"

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
            "permissions" -> result.success(
                mapOf(
                    "supported" to true,
                    "usageAccess" to hasUsageAccess(activity),
                    "overlay" to hasOverlay(activity),
                ),
            )

            "requestUsageAccess" -> {
                activity.startActivity(
                    Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                result.success(null)
            }

            "requestOverlay" -> {
                activity.startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${activity.packageName}"),
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                result.success(null)
            }

            "start" -> {
                val label = call.argument<String>("prayerLabel") ?: "Prayer"
                val endsAt = call.argument<Number>("endsAtMillis")?.toLong()
                    ?: (System.currentTimeMillis() + 30 * 60 * 1000L)

                // Without both grants the service would poll blindly and never
                // be able to surface anything, so we simply do not start it.
                if (!hasUsageAccess(activity) || !hasOverlay(activity)) {
                    result.success(false)
                    return
                }

                val intent = Intent(activity, PrayerLockService::class.java)
                    .setAction(PrayerLockService.ACTION_START)
                    .putExtra(PrayerLockService.EXTRA_LABEL, label)
                    .putExtra(PrayerLockService.EXTRA_ENDS_AT, endsAt)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    activity.startForegroundService(intent)
                } else {
                    activity.startService(intent)
                }
                result.success(true)
            }

            "stop" -> {
                activity.startService(
                    Intent(activity, PrayerLockService::class.java)
                        .setAction(PrayerLockService.ACTION_STOP),
                )
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    fun hasUsageAccess(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE)
            as? AppOpsManager ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun hasOverlay(context: Context): Boolean =
        Settings.canDrawOverlays(context)
}
