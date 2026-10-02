import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'lock_widget.dart';

enum BackgroundType { wallpaper, color, image }

/// A complete lock screen design: background + every widget placed on it.
/// This is the unit that gets serialized for export/import AND for local
/// persistence (see services/theme_storage_service.dart) — [id] is what
/// makes a theme identifiable across app restarts, distinct from its
/// [name] which the user can change freely.
class ThemePack {
  final String id;
  String name;
  BackgroundType backgroundType;
  Color backgroundColor;

  /// Absolute path of a photo copied into the app's documents folder —
  /// only used when [backgroundType] is [BackgroundType.image].
  String? backgroundImagePath;

  /// 0..0.8 black scrim over wallpaper/photo backgrounds for legibility.
  double dim;

  List<LockWidgetConfig> widgets;

  ThemePack({
    String? id,
    required this.name,
    this.backgroundType = BackgroundType.wallpaper,
    this.backgroundColor = Colors.black,
    this.backgroundImagePath,
    this.dim = 0.2,
    List<LockWidgetConfig>? widgets,
  })  : id = id ?? const Uuid().v4(),
        widgets = widgets ?? [];

  bool get useWallpaperBackground => backgroundType == BackgroundType.wallpaper;

  ThemePack copyWith({String? id, String? name}) => ThemePack(
        id: id ?? const Uuid().v4(),
        name: name ?? this.name,
        backgroundType: backgroundType,
        backgroundColor: backgroundColor,
        backgroundImagePath: backgroundImagePath,
        dim: dim,
        widgets: widgets.map((w) => w.copyWith()).toList(),
      );

  /// Deep copy that keeps every id — used for the editor's undo history.
  ThemePack snapshot() => ThemePack.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'backgroundType': backgroundType.name,
        // Kept for the native overlay and for files exported by older versions.
        'useWallpaperBackground': useWallpaperBackground,
        'backgroundColor': backgroundColor.toARGB32(),
        'backgroundImagePath': backgroundImagePath,
        'dim': dim,
        'widgets': widgets.map((w) => w.toJson()).toList(),
      };

  factory ThemePack.fromJson(Map<String, dynamic> json) {
    final type = BackgroundType.values.asNameMap()[json['backgroundType']] ??
        ((json['useWallpaperBackground'] ?? true) ? BackgroundType.wallpaper : BackgroundType.color);
    return ThemePack(
      id: json['id'],
      name: json['name'] ?? 'Imported theme',
      backgroundType: type,
      backgroundColor: Color(json['backgroundColor'] ?? 0xFF000000),
      backgroundImagePath: json['backgroundImagePath'],
      dim: (json['dim'] as num?)?.toDouble() ?? 0.2,
      widgets: (json['widgets'] as List).map((w) => LockWidgetConfig.fromJson(Map<String, dynamic>.from(w))).toList(),
    );
  }
}
