import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Talks to MainActivity's second MethodChannel (see
/// native_lockscreen_snippets/android/MainActivity_REPLACEMENT.kt) to
/// fetch the device's actual wallpaper as PNG bytes. Used by the editor
/// so designing a layout happens against the real backdrop it'll appear
/// over, not a flat color standing in for a photo you won't see until
/// you open the live preview or the real overlay.
class WallpaperService {
  static const _channel = MethodChannel('com.example.lockforge/wallpaper');

  static Future<Uint8List?> fetchWallpaperBytes() async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>('getWallpaperBytes');
      return bytes;
    } catch (_) {
      return null; // caller falls back to the theme's flat background color
    }
  }
}
