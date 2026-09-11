package com.example.lockforge

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * ACTION_SCREEN_ON is an "implicit broadcast" — Android has forbidden
 * declaring a receiver for it in the manifest since API 26, specifically
 * to stop apps from waking up passively in the background. The only way
 * to still observe it is to register the receiver dynamically from a
 * component that's already running — hence this being a persistent
 * foreground service rather than a manifest-registered receiver. This is
 * the same approach every non-root "second lock screen" app uses.
 *
 * Started/stopped by a toggle in the Flutter UI via MainActivity's
 * MethodChannel (see native_lockscreen_snippets/android/MainActivity_additions.kt).
 */
class LockTriggerService : Service() {

    private var receiver: BroadcastReceiver? = null

    override fun onCreate() {
        super.onCreate()
        startForeground(NOTIF_ID, buildNotification())

        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_SCREEN_ON -> {
                        val launch = Intent(context, LockActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
                        }
                        context.startActivity(launch)
                    }
                    Intent.ACTION_USER_PRESENT -> {
                        // Real authentication succeeded — the system is handing
                        // control to the actual home screen. Tell our overlay
                        // Activity (if still around) to finish itself.
                        context.sendBroadcast(Intent(LockActivity.ACTION_DISMISS))
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(receiver, filter)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        receiver?.let { runCatching { unregisterReceiver(it) } }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): android.app.Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "LockForge lock screen", NotificationManager.IMPORTANCE_MIN)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("LockForge lock screen active")
            .setContentText("Your custom design shows when the screen wakes")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "lockforge_trigger"
        private const val NOTIF_ID = 88
    }
}
