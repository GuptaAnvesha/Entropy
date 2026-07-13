package com.entropy.app

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val PERMISSIONS_CHANNEL = "entropy/permissions"
    private val USAGE_STATS_CHANNEL = "entropy/usage_stats"
    private val FOCUS_EVENTS_CHANNEL = "entropy/focus_events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Set up the event channel for focus service
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FOCUS_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    FocusSessionService.eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    FocusSessionService.eventSink = null
                }
            }
        )

        // Set up method channel for permissions
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERMISSIONS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "openUsageAccessSettings" -> {
                    openUsageAccessSettings()
                    result.success(null)
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Set up method channel for usage stats
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_STATS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    result.success(getInstalledApps())
                }
                "getAppUsage" -> {
                    val startTime = call.argument<Long>("startTime") ?: 0L
                    val endTime = call.argument<Long>("endTime") ?: 0L
                    result.success(getAppUsage(startTime, endTime))
                }
                "getHourlyAppUsage" -> {
                    val startTime = call.argument<Long>("startTime") ?: 0L
                    val endTime = call.argument<Long>("endTime") ?: 0L
                    result.success(getHourlyAppUsage(startTime, endTime))
                }
                "getSessionUsage" -> {
                    result.success(FocusSessionService.getUsageSnapshot())
                }
                "startFocusService" -> {
                    val blockedApps = call.argument<List<String>>("blockedApps") ?: emptyList()
                    val intent = Intent(this, FocusSessionService::class.java).apply {
                        putStringArrayListExtra("blockedApps", ArrayList(blockedApps))
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopFocusService" -> {
                    val intent = Intent(this, FocusSessionService::class.java)
                    stopService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
        }
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = packageManager
        val apps = mutableListOf<Map<String, String>>()
        val packages = pm.getInstalledPackages(PackageManager.GET_META_DATA)
        for (pkg in packages) {
            val appInfo = pkg.applicationInfo ?: continue
            val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            if (!isSystemApp || pkg.packageName == "com.android.chrome") {
                val appLabel = pm.getApplicationLabel(appInfo).toString()
                apps.add(mapOf(
                    "name" to appLabel,
                    "packageName" to pkg.packageName
                ))
            }
        }
        apps.sortBy { it["name"]?.lowercase() }
        return apps
    }

    private fun getAppUsage(startTime: Long, endTime: Long): List<Map<String, Any>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
        val usageList = mutableListOf<Map<String, Any>>()
        val pm = packageManager

        if (stats != null) {
            for (usageStat in stats) {
                if (usageStat.totalTimeInForeground > 0) {
                    try {
                        val appInfo = pm.getApplicationInfo(usageStat.packageName, 0)
                        val appName = pm.getApplicationLabel(appInfo).toString()
                        val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                        if (!isSystemApp || usageStat.packageName == "com.android.chrome") {
                            val durationMin = usageStat.totalTimeInForeground.toDouble() / 60000.0
                            if (durationMin > 0.05) {
                                usageList.add(mapOf(
                                    "appName" to appName,
                                    "packageName" to usageStat.packageName,
                                    "durationMinutes" to durationMin
                                ))
                            }
                        }
                    } catch (e: PackageManager.NameNotFoundException) {
                        // Skip
                    }
                }
            }
        }
        return usageList
    }

    // Day x hour usage buckets built from raw foreground/background events.
    // Returns one entry per (app, dateKey, hour) with the minutes the app
    // spent in the foreground inside that hour.
    private fun getHourlyAppUsage(startTime: Long, endTime: Long): List<Map<String, Any>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(startTime, endTime)
        val pm = packageManager
        val event = UsageEvents.Event()
        val foregroundSince = HashMap<String, Long>()
        val bucketMillis = HashMap<String, Long>()
        val dateFormat = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US)
        val cal = java.util.Calendar.getInstance()

        fun addInterval(pkg: String, from: Long, to: Long) {
            var cursor = from
            while (cursor < to) {
                cal.timeInMillis = cursor
                val hour = cal.get(java.util.Calendar.HOUR_OF_DAY)
                cal.set(java.util.Calendar.MINUTE, 0)
                cal.set(java.util.Calendar.SECOND, 0)
                cal.set(java.util.Calendar.MILLISECOND, 0)
                val hourEnd = cal.timeInMillis + 3600000L
                val sliceEnd = minOf(to, hourEnd)
                val key = "$pkg|${dateFormat.format(java.util.Date(cursor))}|$hour"
                bucketMillis[key] = (bucketMillis[key] ?: 0L) + (sliceEnd - cursor)
                cursor = sliceEnd
            }
        }

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND ->
                    foregroundSince[event.packageName] = event.timeStamp
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val start = foregroundSince.remove(event.packageName)
                    if (start != null && event.timeStamp > start) {
                        addInterval(event.packageName, start, event.timeStamp)
                    }
                }
            }
        }
        // Close out any app still in the foreground at the end of the window
        for ((pkg, start) in foregroundSince) {
            if (endTime > start) addInterval(pkg, start, endTime)
        }

        val usageList = mutableListOf<Map<String, Any>>()
        for ((key, millis) in bucketMillis) {
            val parts = key.split("|")
            val pkg = parts[0]
            try {
                val appInfo = pm.getApplicationInfo(pkg, 0)
                val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                if (isSystemApp && pkg != "com.android.chrome") continue
                val durationMin = millis.toDouble() / 60000.0
                if (durationMin < 0.05) continue
                usageList.add(mapOf(
                    "appName" to pm.getApplicationLabel(appInfo).toString(),
                    "packageName" to pkg,
                    "dateKey" to parts[1],
                    "hour" to parts[2].toInt(),
                    "durationMinutes" to durationMin
                ))
            } catch (e: PackageManager.NameNotFoundException) {
                // Skip
            }
        }
        return usageList
    }
}
