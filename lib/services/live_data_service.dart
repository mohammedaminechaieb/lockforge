import 'dart:async';
import 'package:flutter/material.dart';
import 'calendar_service.dart';
import 'health_service.dart';
import 'weather_service.dart';

/// Last-known values for the data-driven widget types, formatted the way
/// they're displayed. Shared by the live preview and by the push to the
/// native lock screen, so both always show the same text.
class LiveValues {
  final String weather;
  final String steps;
  final String calendar;
  const LiveValues({required this.weather, required this.steps, required this.calendar});

  Map<String, String> toJson() => {'weather': weather, 'steps': steps, 'calendar': calendar};
}

class LiveDataService {
  /// Fetches everything in parallel. Each source fails soft to a "--"
  /// placeholder (no permission, no sensor, offline…) instead of throwing.
  static Future<LiveValues> fetch({bool use24h = true}) async {
    final results = await Future.wait([
      _weather(),
      _steps(),
      _calendar(use24h),
    ]);
    return LiveValues(weather: results[0], steps: results[1], calendar: results[2]);
  }

  static Future<String> _weather() async {
    final reading = await WeatherService().fetchCurrent();
    return reading == null ? '--' : '${reading.condition} ${reading.tempCelsius.round()}°C';
  }

  static Future<String> _steps() async {
    try {
      final steps = await HealthService().stepCountStream().first.timeout(const Duration(seconds: 4));
      return '$steps steps';
    } catch (_) {
      return '-- steps';
    }
  }

  static Future<String> _calendar(bool use24h) async {
    try {
      final event = await CalendarService().fetchNextEvent();
      if (event == null) return 'No events today';
      final t = TimeOfDay.fromDateTime(event.start);
      final time = use24h
          ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
          : '${t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
      return '${event.title} · $time';
    } catch (_) {
      return 'No events today';
    }
  }
}
