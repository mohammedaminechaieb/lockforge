import 'package:flutter/material.dart';
import 'lock_widget.dart';
import 'theme_pack.dart';

/// A handful of genuinely different starting points, not just one
/// generic layout — matches what any theme-driven app (icon packs,
/// launchers) ships so a new user has something to pick from that looks
/// intentional rather than a blank canvas or a single obvious default.
class StarterThemes {
  static List<ThemePack> all() => [minimal(), boldWeather(), dailyBrief(), cleanText()];

  static ThemePack minimal() => ThemePack(
        name: 'Minimal',
        useWallpaperBackground: true,
        widgets: [
          LockWidgetConfig(type: LockWidgetType.clock, xFraction: 0.5, yFraction: 0.22, fontSize: 64, fontWeight: FontWeight.w200),
        ],
      );

  static ThemePack boldWeather() => ThemePack(
        name: 'Bold Weather',
        useWallpaperBackground: true,
        widgets: [
          LockWidgetConfig(type: LockWidgetType.clock, xFraction: 0.5, yFraction: 0.18, fontSize: 72, fontWeight: FontWeight.bold),
          LockWidgetConfig(type: LockWidgetType.weather, xFraction: 0.5, yFraction: 0.28, fontSize: 22),
        ],
      );

  static ThemePack dailyBrief() => ThemePack(
        name: 'Daily Brief',
        useWallpaperBackground: true,
        widgets: [
          LockWidgetConfig(type: LockWidgetType.clock, xFraction: 0.5, yFraction: 0.16, fontSize: 56, fontWeight: FontWeight.w300, showDateWithClock: true),
          LockWidgetConfig(type: LockWidgetType.weather, xFraction: 0.5, yFraction: 0.30, fontSize: 18),
          LockWidgetConfig(type: LockWidgetType.calendar, xFraction: 0.5, yFraction: 0.36, fontSize: 15),
          LockWidgetConfig(type: LockWidgetType.steps, xFraction: 0.5, yFraction: 0.41, fontSize: 14),
        ],
      );

  static ThemePack cleanText() => ThemePack(
        name: 'Clean & Simple',
        useWallpaperBackground: true,
        widgets: [
          LockWidgetConfig(type: LockWidgetType.clock, xFraction: 0.5, yFraction: 0.20, fontSize: 60, fontWeight: FontWeight.w200, use24HourClock: false),
          LockWidgetConfig(type: LockWidgetType.text, xFraction: 0.5, yFraction: 0.30, fontSize: 16, customText: 'Have a great day'),
        ],
      );
}
