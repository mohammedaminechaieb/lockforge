package com.example.lockforge

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * ACTION_SCREEN_ON can't be received by a manifest receiver since API 26,
 * so a running foreground service registers for it dynamically and opens
 * LockActivity each time the screen wakes. Started/stopped from Dart via
 * MainActivity's MethodChannel.
 */
class LockTriggerService : Service() {

    private var receiver: BroadcastReceiver? = null

    override fun onCreate() {
        super.onCreate()
        ServiceCompat.startForeground(
            this, NOTIF_ID, buildNotification(),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE else 0
        )

        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                when (intent.action) {
                    Intent.ACTION_SCREEN_ON -> {
                        // Without "display over other apps", Android 10+ silently
                        // blocks this launch — the settings screen checks for it.
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || Settings.canDrawOverlays(context)) {
                            context.startActivity(
                                Intent(context, LockActivity::class.java)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_USER_ACTION)
                            )
                        }
                    }
                    Intent.ACTION_USER_PRESENT -> {
                        // Real authentication succeeded — close our themed layer.
                        context.sendBroadcast(Intent(LockActivity.ACTION_DISMISS).setPackage(context.packageName))
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
            val channel = NotificationChannel(CHANNEL_ID, "Custom lock screen", NotificationManager.IMPORTANCE_MIN)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val openApp = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("LockForge lock screen is on")
            .setContentText("Tap to change your design")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentIntent(openApp)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CHANNEL_ID = "lockforge_trigger"
        private const val NOTIF_ID = 88
    }
}
