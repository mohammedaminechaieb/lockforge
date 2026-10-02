import 'package:flutter/services.dart';

/// Fetches the device's wallpaper as PNG bytes for the editor backdrop.
/// Android only allows this on some versions/devices (13+ restricts it), so
/// callers must handle null — the real lock screen still shows the actual
/// wallpaper either way, because it draws through a transparent window.
class WallpaperService {
  static const _channel = MethodChannel('com.example.lockforge/wallpaper');
  static Uint8List? _cache;
  static bool _tried = false;

  static Future<Uint8List?> fetchWallpaperBytes() async {
    if (_tried) return _cache;
    try {
      _cache = await _channel.invokeMethod<Uint8List>('getWallpaperBytes');
    } catch (_) {
      _cache = null;
    }
    _tried = true;
    return _cache;
  }
}
