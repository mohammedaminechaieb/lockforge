package com.example.lockforge

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.view.WindowManager

/**
 * Shown the instant LockTriggerService sees ACTION_SCREEN_ON.
 * setShowWhenLocked(true) + setTurnScreenOn(true) is the officially
 * supported (still non-root) way for an Activity to display over the
 * keyguard — this is the same mechanism incoming-call screens and alarm
 * apps use to show over a locked device. It does NOT bypass or replace
 * the device's real security: if the device has a PIN/pattern/biometric
 * set, Android still enforces that before granting access to anything
 * behind this screen. What varies by Android version/OEM is exactly when
 * the real secure keyguard UI appears alongside this — on some builds
 * it's immediately layered, on others it only appears once the user
 * tries to proceed (swipe/tap). Either way, security is never weakened;
 * this is a themed layer at the wake moment, not an unlock mechanism.
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
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        setContentView(LockOverlayView(this) { finish() }) // tap-to-dismiss, like a real lock screen

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
