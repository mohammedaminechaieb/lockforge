package com.example.lockforge

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/**
 * Shown the instant LockTriggerService sees ACTION_SCREEN_ON.
 * setShowWhenLocked(true) + setTurnScreenOn(true) is the supported
 * non-root way to display over the keyguard (alarm and call screens use
 * it). It does NOT bypass security: with a PIN/pattern/biometric set,
 * Android still requires it before anything behind this screen.
 *
 * Its theme (LockOverlayTheme) is a transparent window with
 * windowShowWallpaper, so the user's real wallpaper shows through.
 */
class LockActivity : Activity() {

    private val dismissReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == ACTION_DISMISS) finish()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        }

        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowCompat.getInsetsController(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.navigationBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }

        setContentView(LockOverlayView(this) { finish() })

        val filter = IntentFilter(ACTION_DISMISS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(dismissReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(dismissReceiver, filter)
        }
    }

    override fun onDestroy() {
        runCatching { unregisterReceiver(dismissReceiver) }
        super.onDestroy()
    }

    companion object {
        const val ACTION_DISMISS = "com.example.lockforge.ACTION_DISMISS_LOCK_OVERLAY"
    }
}
