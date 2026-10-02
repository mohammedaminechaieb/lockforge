import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../models/theme_pack.dart';
import 'live_data_service.dart';

/// Pushes state into shared native storage read by two consumers:
///   - LockForgeWidgetProvider (home-screen AppWidget, fixed layout with a
///     live TextClock) reads event_label/weather_label.
///   - LockOverlayView (the real wake-screen overlay, native Canvas) reads
///     theme_json/live_values_json and renders the ENTIRE design.
class HomeWidgetService {
  static const _appGroupId = 'group.com.example.lockforge'; // iOS only, harmless on Android
  static const _androidWidgetProvider = 'LockForgeWidgetProvider';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Sends the design plus fresh live values to the lock screen overlay and
  /// the home-screen widget in one go.
  static Future<void> pushAll(ThemePack theme, LiveValues live) async {
    await HomeWidget.saveWidgetData<String>('theme_json', jsonEncode(theme.toJson()));
    await HomeWidget.saveWidgetData<String>('live_values_json', jsonEncode(live.toJson()));
    await HomeWidget.saveWidgetData<String>('event_label', live.calendar);
    await HomeWidget.saveWidgetData<String>('weather_label', live.weather == '--' ? '' : live.weather);
    await HomeWidget.updateWidget(androidName: _androidWidgetProvider, iOSName: 'LockForgeWidget');
  }

  /// Design-only push (no network/sensor calls) — used after every edit to
  /// the active theme so the lock screen always matches the editor.
  static Future<void> pushTheme(ThemePack theme) async {
    await HomeWidget.saveWidgetData<String>('theme_json', jsonEncode(theme.toJson()));
  }
}
