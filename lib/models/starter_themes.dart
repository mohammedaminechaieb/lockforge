import 'package:flutter/material.dart';
import 'lock_widget.dart';
import 'theme_pack.dart';

/// A handful of genuinely different starting points, so a new theme never
/// starts from an intimidating blank canvas. Positions are widget centers.
class StarterThemes {
  static List<ThemePack> all() => [minimal(), boldWeather(), dailyBrief(), cleanText(), midnight()];

  static ThemePack minimal() => ThemePack(
        name: 'Minimal',
        widgets: [
          LockWidgetConfig(type: LockWidgetType.clock, xFraction: 0.5, yFraction: 0.22, fontSize: 72, fontWeight: FontWeight.w200),
          LockWidgetConfig(type: LockWidgetType.date, xFraction: 0.5, yFraction: 0.30, fontSize: 16),
        ],
      );

  static ThemePack boldWeather() => ThemePack(
        name: 'Bold Weather',
        widgets: [
          LockWidgetConfig(type: LockWidgetType.clock, xFraction: 0.5, yFraction: 0.20, fontSize: 84, fontWeight: FontWeight.w700),
          LockWidgetConfig(type: LockWidgetType.weather, xFraction: 0.5, yFraction: 0.31, fontSize: 22),
        ],
      );

  static ThemePack dailyBrief() => ThemePack(
        name: 'Daily Brief',
        widgets: [
          LockWidgetConfig(type: LockWidgetType.clock, xFraction: 0.5, yFraction: 0.17, fontSize: 64, fontWeight: FontWeight.w200, showDateWithClock: true),
          LockWidgetConfig(type: LockWidgetType.weather, xFraction: 0.5, yFraction: 0.30, fontSize: 18),
          LockWidgetConfig(type: LockWidgetType.calendar, xFraction: 0.5, yFraction: 0.35, fontSize: 15),
          LockWidgetConfig(type: LockWidgetType.steps, xFraction: 0.5, yFraction: 0.40, fontSize: 14),
        ],
      );

  static ThemePack cleanText() => ThemePack(
        name: 'Clean & Simple',
        widgets: [
          LockWidgetConfig(type: LockWidgetType.clock, xFraction: 0.5, yFraction: 0.20, fontSize: 64, fontWeight: FontWeight.w200, use24HourClock: false),
          LockWidgetConfig(type: LockWidgetType.text, xFraction: 0.5, yFraction: 0.30, fontSize: 16, customText: 'Have a great day'),
        ],
      );

  static ThemePack midnight() => ThemePack(
        name: 'Midnight',
        backgroundType: BackgroundType.color,
        backgroundColor: const Color(0xFF0B1026),
        widgets: [
          LockWidgetConfig(type: LockWidgetType.date, xFraction: 0.5, yFraction: 0.13, fontSize: 15, color: const Color(0xFF8C9EFF)),
          LockWidgetConfig(type: LockWidgetType.clock, xFraction: 0.5, yFraction: 0.21, fontSize: 88, fontWeight: FontWeight.w200, color: const Color(0xFFE8EAF6)),
          LockWidgetConfig(type: LockWidgetType.calendar, xFraction: 0.5, yFraction: 0.85, fontSize: 14, color: const Color(0xFF8C9EFF)),
        ],
      );
}
