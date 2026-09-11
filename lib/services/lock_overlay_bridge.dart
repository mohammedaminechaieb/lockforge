import 'package:flutter/services.dart';

/// Talks to MainActivity's MethodChannel (see
/// native_lockscreen_snippets/android/MainActivity_REPLACEMENT.kt) to
/// start/stop the native LockTriggerService that shows the designed
/// theme over the wake screen.
class LockOverlayBridge {
  static const _channel = MethodChannel('com.example.lockforge/lock_overlay');

  static Future<void> setEnabled(bool enabled) async {
    await _channel.invokeMethod('setEnabled', enabled);
  }

  static Future<bool> isEnabled() async {
    final result = await _channel.invokeMethod<bool>('isEnabled');
    return result ?? false;
  }
}
