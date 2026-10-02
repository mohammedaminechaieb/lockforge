package com.example.lockforge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * Reads the same "lock_overlay_enabled" flag MainActivity's channel writes
 * so the custom lock screen comes back after a reboot without the user
 * re-opening the app. BOOT_COMPLETED is one of the exemptions that allows
 * starting a foreground service from the background.
 */
class LockBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val prefs = context.getSharedPreferences("lockforge_native_prefs", Context.MODE_PRIVATE)
        if (!prefs.getBoolean("lock_overlay_enabled", false)) return

        runCatching { ContextCompat.startForegroundService(context, Intent(context, LockTriggerService::class.java)) }
    }
}
