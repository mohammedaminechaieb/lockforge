import 'package:flutter/services.dart';

/// Talks to MainActivity's MethodChannel (android/app/src/main/kotlin/…/
/// MainActivity.kt) to start/stop the native LockTriggerService that shows
/// the designed theme when the screen wakes, and to check the permissions
/// that feature depends on.
class LockOverlayBridge {
  static const _channel = MethodChannel('com.example.lockforge/lock_overlay');

  static Future<void> setEnabled(bool enabled) async {
    await _channel.invokeMethod('setEnabled', enabled);
  }

  static Future<bool> isEnabled() async {
    final result = await _channel.invokeMethod<bool>('isEnabled');
    return result ?? false;
  }

  /// "Display over other apps" — Android 10+ only lets a background
  /// service open the lock screen activity when this is granted.
  static Future<bool> canDrawOverlays() async {
    return await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
  }

  static Future<void> openOverlaySettings() => _channel.invokeMethod('openOverlaySettings');

  /// Android 13+ notification permission — needed for the small "lock
  /// screen active" notification a foreground service must show.
  static Future<bool> hasNotificationPermission() async {
    return await _channel.invokeMethod<bool>('hasNotificationPermission') ?? true;
  }

  static Future<void> requestNotificationPermission() => _channel.invokeMethod('requestNotificationPermission');

  /// Shows the overlay right now, without having to turn the screen off and on.
  static Future<void> showNow() => _channel.invokeMethod('showNow');
}
