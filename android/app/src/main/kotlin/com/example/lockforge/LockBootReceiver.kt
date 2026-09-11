package com.example.lockforge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build

/**
 * Reads the same "lock_overlay_enabled" flag the MethodChannel bridge
 * writes (see MainActivity_additions.kt) so the overlay comes back after
 * a reboot without the user having to re-open the app and re-toggle it.
 */
class LockBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs: SharedPreferences = context.getSharedPreferences("lockforge_native_prefs", Context.MODE_PRIVATE)
        val wasEnabled = prefs.getBoolean("lock_overlay_enabled", false)
        if (!wasEnabled) return

        val serviceIntent = Intent(context, LockTriggerService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
