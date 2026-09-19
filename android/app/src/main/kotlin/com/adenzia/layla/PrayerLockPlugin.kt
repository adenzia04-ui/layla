package com.adenzia.layla

import android.app.Activity
import android.app.AppOpsManager
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import java.io.ByteArrayOutputStream
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

            // The day's windows, handed over so the lock can engage with
            // Flutter dead. iOS gives these to DeviceActivity and Apple does
            // the rest; Android has no such service, so the app books its own
            // alarms. Passing an empty list turns the schedule off.
            "scheduleWindows" -> {
                val raw = call.argument<List<Map<String, Any?>>>("windows")
                    ?: emptyList()
                val windows = raw.mapNotNull { row ->
                    val start = (row["startMs"] as? Number)?.toLong()
                    val end = (row["endMs"] as? Number)?.toLong()
                    if (start == null || end == null || end <= start) {
                        null
                    } else {
                        LockStore.Window(
                            (row["label"] as? String) ?: "Prayer",
                            start,
                            end,
                        )
                    }
                }
                LockStore.setWindows(activity, windows)
                LockStore.setEnabled(activity, windows.isNotEmpty())
                PrayerWindowReceiver.reschedule(activity)
                result.success(true)
            }

            // Which apps this person chose to pause. Stored on the phone and
            // read by the service; never sent anywhere.
            "setBlockedPackages" -> {
                val packages = call.argument<List<String>>("packages")
                    ?: emptyList()
                LockStore.setBlocked(activity, packages.toSet())
                result.success(true)
            }

            "blockedPackages" ->
                result.success(LockStore.blocked(activity).toList())

            // Everything with a launcher icon, for the app picker. Apple hands
            // back opaque tokens and never tells the app what was chosen;
            // Android has no such picker, so Layla draws its own and has to
            // read the list itself.
            "installedApps" -> result.success(installedApps(activity))

            else -> result.notImplemented()
        }
    }

    /**
     * Apps with a launcher entry, minus this one, newest ordering left to the
     * caller.
     *
     * Icons travel as PNG bytes rather than paths: the picker is Flutter and
     * cannot read another package's resources. They are capped at 96px, which
     * is enough for a list row and keeps the whole payload to a few hundred
     * kilobytes rather than several megabytes.
     */
    private fun installedApps(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val launchable = Intent(Intent.ACTION_MAIN)
            .addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = pm.queryIntentActivities(launchable, 0)
        val seen = HashSet<String>()
        val apps = ArrayList<Map<String, Any?>>()
        for (info in resolved) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == context.packageName) continue
            if (!seen.add(pkg)) continue
            val appInfo: ApplicationInfo = try {
                pm.getApplicationInfo(pkg, 0)
            } catch (error: PackageManager.NameNotFoundException) {
                continue
            }
            apps.add(
                mapOf(
                    "package" to pkg,
                    "label" to pm.getApplicationLabel(appInfo).toString(),
                    "system" to
                        ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                    "icon" to iconBytes(pm.getApplicationIcon(appInfo)),
                ),
            )
        }
        apps.sortBy { (it["label"] as String).lowercase() }
        return apps
    }

    private fun iconBytes(drawable: Drawable): ByteArray? = try {
        val size = 96
        val bitmap = if (
            drawable is BitmapDrawable && drawable.bitmap != null
        ) {
            Bitmap.createScaledBitmap(drawable.bitmap, size, size, true)
        } else {
            Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888).also { bmp ->
                val canvas = Canvas(bmp)
                drawable.setBounds(0, 0, size, size)
                drawable.draw(canvas)
            }
        }
        ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        }
    } catch (error: Exception) {
        null
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
