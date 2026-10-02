package com.example.lockforge

import android.Manifest
import android.app.WallpaperManager
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Two MethodChannels:
 *   - "com.example.lockforge/lock_overlay": start/stop LockTriggerService
 *     (persisted so LockBootReceiver can restore it), plus the permission
 *     checks/requests that feature depends on.
 *   - "com.example.lockforge/wallpaper": the device wallpaper as PNG bytes
 *     for the editor backdrop. Android 13+ usually refuses this, so Dart
 *     treats null as "show a placeholder" — the real lock screen doesn't
 *     need it, since LockActivity draws over the wallpaper directly.
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
                        runCatching { ContextCompat.startForegroundService(this, serviceIntent) }
                    } else {
                        stopService(serviceIntent)
                    }
                    result.success(null)
                }
                "isEnabled" -> result.success(prefs.getBoolean("lock_overlay_enabled", false))
                "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
                "openOverlaySettings" -> {
                    startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                "hasNotificationPermission" -> result.success(hasNotificationPermission())
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !hasNotificationPermission()) {
                        if (ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.POST_NOTIFICATIONS) ||
                            !prefs.getBoolean("asked_notifications", false)
                        ) {
                            prefs.edit().putBoolean("asked_notifications", true).apply()
                            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 41)
                        } else {
                            // Permanently denied — the only way back is the app's notification settings.
                            startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                        }
                    }
                    result.success(null)
                }
                "showNow" -> {
                    startActivity(Intent(this, LockActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wallpaperChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getWallpaperBytes" -> {
                    val bytes = runCatching {
                        val bitmap = (WallpaperManager.getInstance(this).drawable as? BitmapDrawable)?.bitmap
                        bitmap?.let {
                            // Downscale: the editor shows it small, and a full-res
                            // PNG over the channel is slow and memory-hungry.
                            val scale = 1080f / maxOf(it.width, it.height).coerceAtLeast(1080)
                            val scaled = Bitmap.createScaledBitmap(it, (it.width * scale).toInt(), (it.height * scale).toInt(), true)
                            ByteArrayOutputStream().also { out -> scaled.compress(Bitmap.CompressFormat.JPEG, 88, out) }.toByteArray()
                        }
                    }.getOrNull()
                    result.success(bytes)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
}
