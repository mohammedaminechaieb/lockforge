package com.example.lockforge

import android.app.WallpaperManager
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.os.Build
import java.io.ByteArrayOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * This REPLACES the MainActivity.kt that `flutter create` generated —
 * it's normally just a bare `class MainActivity: FlutterActivity()` with
 * no body. Copy this whole file over it (same package line, same file
 * path) rather than trying to patch the original line-by-line.
 *
 * Two MethodChannels:
 *   - "com.example.lockforge/lock_overlay" (unchanged from before):
 *       "setEnabled" (bool) → starts/stops LockTriggerService and persists
 *                             the choice so LockBootReceiver can restore it
 *       "isEnabled"         → returns the persisted flag
 *   - "com.example.lockforge/wallpaper" (NEW):
 *       "getWallpaperBytes" → returns the device's current wallpaper as
 *                             PNG bytes, so the EDITOR can show the real
 *                             wallpaper as its backdrop instead of a flat
 *                             color standing in for a photo you won't see
 *                             until later. Same WallpaperManager API
 *                             LockOverlayView already uses for the real
 *                             overlay — this just exposes it to Dart too.
 */
class MainActivity : FlutterActivity() {
    private val overlayChannelName = "com.example.lockforge/lock_overlay"
    private val wallpaperChannelName = "com.example.lockforge/wallpaper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val prefs: SharedPreferences = getSharedPreferences("lockforge_native_prefs", MODE_PRIVATE)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, overlayChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    val enabled = call.arguments as? Boolean ?: false
                    prefs.edit().putBoolean("lock_overlay_enabled", enabled).apply()

                    val serviceIntent = Intent(this, LockTriggerService::class.java)
                    if (enabled) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(serviceIntent) else startService(serviceIntent)
                    } else {
                        stopService(serviceIntent)
                    }
                    result.success(null)
                }
                "isEnabled" -> {
                    result.success(prefs.getBoolean("lock_overlay_enabled", false))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wallpaperChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getWallpaperBytes" -> {
                    val bytes = runCatching {
                        val drawable = WallpaperManager.getInstance(this).drawable
                        val bitmap = (drawable as? BitmapDrawable)?.bitmap
                        if (bitmap == null) null else {
                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
                            stream.toByteArray()
                        }
                    }.getOrNull()
                    result.success(bytes)
                }
                else -> result.notImplemented()
            }
        }
    }
}
