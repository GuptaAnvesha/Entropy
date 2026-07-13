package com.entropy.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class FocusSessionService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var blockedApps: List<String>
    private val NOTIF_ID = 8888
    private val CHANNEL_ID = "focus_session_channel"
    private var startTimeMillis = 0L
    private var lastForegroundPackage: String? = null
    private val appLabelCache = HashMap<String, String>()
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    companion object {
        var eventSink: EventChannel.EventSink? = null

        private const val POLL_INTERVAL_MS = 4000L

        // Per-app usage accumulated during the current focus session,
        // keyed by "package|yyyy-MM-dd|hour" -> seconds in foreground.
        // Lives in the companion so Flutter can read the final snapshot
        // even after the service is stopped; reset on each session start.
        private val usageSeconds = HashMap<String, Long>()
        private val labelByKey = HashMap<String, String>()

        @Synchronized
        fun accumulate(packageName: String, label: String, dateKey: String, hour: Int, seconds: Long) {
            val key = "$packageName|$dateKey|$hour"
            usageSeconds[key] = (usageSeconds[key] ?: 0L) + seconds
            labelByKey[key] = label
        }

        @Synchronized
        fun resetUsage() {
            usageSeconds.clear()
            labelByKey.clear()
        }

        @Synchronized
        fun getUsageSnapshot(): List<Map<String, Any>> {
            return usageSeconds.map { (key, seconds) ->
                val parts = key.split("|")
                mapOf(
                    "packageName" to parts[0],
                    "appName" to (labelByKey[key] ?: parts[0]),
                    "dateKey" to parts[1],
                    "hour" to parts[2].toInt(),
                    "durationMinutes" to seconds.toDouble() / 60.0
                )
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        blockedApps = intent?.getStringArrayListExtra("blockedApps") ?: emptyList()
        startTimeMillis = System.currentTimeMillis()
        lastForegroundPackage = null
        resetUsage()

        startForeground(NOTIF_ID, buildNotification("Focus session active"))
        handler.post(pollRunnable)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }

    private val pollRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    private fun checkForegroundApp() {
        // Skip ticks while the screen is off: queryUsageStats would keep
        // reporting the last-used app and pollute the usage attribution.
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isInteractive) return

        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 10000, now)
        val foregroundApp = stats?.maxByOrNull { it.lastTimeUsed }?.packageName ?: return

        val elapsedSeconds = ((now - startTimeMillis) / 1000).toInt()

        // Attribute this poll tick to the foreground app, bucketed by day and hour.
        if (foregroundApp != packageName) {
            val cal = Calendar.getInstance()
            cal.timeInMillis = now
            accumulate(
                foregroundApp,
                getAppLabel(foregroundApp),
                dateFormat.format(Date(now)),
                cal.get(Calendar.HOUR_OF_DAY),
                POLL_INTERVAL_MS / 1000
            )
        }

        // Notify Flutter when the foreground app changes (live session data).
        if (foregroundApp != lastForegroundPackage) {
            lastForegroundPackage = foregroundApp
            val label = getAppLabel(foregroundApp)
            eventSink?.success(mapOf(
                "event" to "current_app",
                "package" to foregroundApp,
                "appName" to label,
                "elapsedSeconds" to elapsedSeconds
            ))
            val text = if (foregroundApp == packageName) "Focus session active"
                       else "Focus session active — $label"
            val manager = getSystemService(NotificationManager::class.java)
            manager?.notify(NOTIF_ID, buildNotification(text))
        }

        if (blockedApps.contains(foregroundApp)) {
            eventSink?.success(mapOf(
                "event" to "blocked_app_detected",
                "package" to foregroundApp,
                "elapsedSeconds" to elapsedSeconds
            ))
        }
    }

    private fun getAppLabel(packageName: String): String {
        return appLabelCache.getOrPut(packageName) {
            try {
                val appInfo = packageManager.getApplicationInfo(packageName, 0)
                packageManager.getApplicationLabel(appInfo).toString()
            } catch (e: PackageManager.NameNotFoundException) {
                packageName.substringAfterLast('.')
            }
        }
    }

    private fun buildNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Entropy Focus Mode")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Focus Session Service Channel",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }
}
