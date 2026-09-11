import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'lock_widget.dart';

/// A complete lock screen design: background + every widget placed on it.
/// This is the unit that gets serialized for export/import AND for local
/// persistence (see services/theme_storage_service.dart) — [id] is what
/// makes a theme identifiable across app restarts and across the gallery
/// of saved themes, distinct from its [name] which the user can change
/// freely without losing its saved identity.
class ThemePack {
  final String id;
  String name;
  Color backgroundColor;

  /// When true, the editor and preview show the device's real wallpaper
  /// as the backdrop instead of [backgroundColor] — this is what makes
  /// designing in the editor actually match what the real lock screen
  /// (and the native overlay) will look like, rather than a flat color
  /// standing in for a photo you'll see later and not before.
  bool useWallpaperBackground;

  List<LockWidgetConfig> widgets;

  ThemePack({
    String? id,
    required this.name,
    this.backgroundColor = Colors.black,
    this.useWallpaperBackground = true,
    List<LockWidgetConfig>? widgets,
  })  : id = id ?? const Uuid().v4(),
        widgets = widgets ?? [];

  ThemePack copyWith({String? id, String? name}) => ThemePack(
        id: id ?? const Uuid().v4(),
        name: name ?? this.name,
        backgroundColor: backgroundColor,
        useWallpaperBackground: useWallpaperBackground,
        widgets: widgets.map((w) => w.copyWith()).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'backgroundColor': backgroundColor.value,
        'useWallpaperBackground': useWallpaperBackground,
        'widgets': widgets.map((w) => w.toJson()).toList(),
      };

  factory ThemePack.fromJson(Map<String, dynamic> json) => ThemePack(
        id: json['id'],
        name: json['name'] ?? 'Imported theme',
        backgroundColor: Color(json['backgroundColor'] ?? Colors.black.value),
        useWallpaperBackground: json['useWallpaperBackground'] ?? true,
        widgets: (json['widgets'] as List).map((w) => LockWidgetConfig.fromJson(w)).toList(),
      );
}
