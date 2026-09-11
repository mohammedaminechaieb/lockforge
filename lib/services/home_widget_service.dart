import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import '../models/theme_pack.dart';

/// Pushes state into shared native storage two different consumers read:
///   - LockForgeWidgetProvider (home-screen AppWidget, fixed layout)
///     reads time_label/event_label/weather_label — pushed by pushState().
///   - LockOverlayView (the real wake-screen overlay, native Canvas)
///     reads theme_json/live_values_json — pushed by pushLockScreenState().
///     Because that overlay is a window we fully own (not a RemoteViews
///     AppWidget), it can render the ENTIRE arbitrary canvas design, not
///     just one fixed layout — see LockOverlayView.kt's class doc.
class HomeWidgetService {
  static const _appGroupId = 'group.com.example.lockforge'; // iOS only, harmless on Android
  static const _androidWidgetProvider = 'LockForgeWidgetProvider';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Feeds the fixed-layout home-screen widget (unchanged from before).
  static Future<void> pushState({
    required String timeLabel,
    String? eventLabel,
    String? weatherLabel,
  }) async {
    await HomeWidget.saveWidgetData<String>('time_label', timeLabel);
    await HomeWidget.saveWidgetData<String>('event_label', eventLabel ?? 'No events today');
    await HomeWidget.saveWidgetData<String>('weather_label', weatherLabel ?? '');
    await HomeWidget.updateWidget(
      androidName: _androidWidgetProvider,
      iOSName: 'LockForgeWidget',
    );
  }

  /// Feeds the real wake-screen overlay with the full designed theme
  /// (every widget, its type/position/size/color) plus a small map of
  /// last-known live values for the data-driven widget types. Call this
  /// whenever the user finalizes a design (e.g. taps "Set as Lock
  /// Screen") and again periodically while the app is open so the live
  /// values don't go too stale — the overlay itself has no way to fetch
  /// weather/calendar/steps on its own since those need Dart's services.
  static Future<void> pushLockScreenState({
    required ThemePack theme,
    String? weatherLabel,
    String? stepsLabel,
    String? calendarLabel,
  }) async {
    final liveValues = {
      'weather': weatherLabel ?? '--',
      'steps': stepsLabel ?? '-- steps',
      'calendar': calendarLabel ?? 'No events today',
    };
    await HomeWidget.saveWidgetData<String>('theme_json', jsonEncode(theme.toJson()));
    await HomeWidget.saveWidgetData<String>('live_values_json', jsonEncode(liveValues));
  }
}
