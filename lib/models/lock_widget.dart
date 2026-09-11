import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum LockWidgetType { clock, weather, steps, calendar, text }

/// One draggable element on the lock screen canvas. Position is stored as
/// a fraction (0..1) of the canvas width/height so a layout looks the same
/// on any device size, not just the one it was designed on.
class LockWidgetConfig {
  final String id;
  LockWidgetType type;
  double xFraction;
  double yFraction;
  double fontSize;
  String fontFamily; // must match a family registered in pubspec.yaml, or "" for default
  Color color;
  String customText; // only used when type == text
  FontWeight fontWeight;

  // Clock-only formatting options — ignored for every other widget type.
  bool use24HourClock;
  bool showSeconds;
  bool showDateWithClock;

  LockWidgetConfig({
    String? id,
    required this.type,
    this.xFraction = 0.5,
    this.yFraction = 0.5,
    this.fontSize = 24,
    this.fontFamily = "",
    this.color = Colors.white,
    this.customText = "Your text",
    this.fontWeight = FontWeight.normal,
    this.use24HourClock = true,
    this.showSeconds = false,
    this.showDateWithClock = false,
  }) : id = id ?? const Uuid().v4();

  LockWidgetConfig copyWith() => LockWidgetConfig(
        id: const Uuid().v4(),
        type: type,
        xFraction: xFraction,
        yFraction: yFraction,
        fontSize: fontSize,
        fontFamily: fontFamily,
        color: color,
        customText: customText,
        fontWeight: fontWeight,
        use24HourClock: use24HourClock,
        showSeconds: showSeconds,
        showDateWithClock: showDateWithClock,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': xFraction,
        'y': yFraction,
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'color': color.value,
        'customText': customText,
        'fontWeight': fontWeight.index,
        'use24HourClock': use24HourClock,
        'showSeconds': showSeconds,
        'showDateWithClock': showDateWithClock,
      };

  factory LockWidgetConfig.fromJson(Map<String, dynamic> json) => LockWidgetConfig(
        id: json['id'],
        type: LockWidgetType.values.byName(json['type']),
        xFraction: (json['x'] as num).toDouble(),
        yFraction: (json['y'] as num).toDouble(),
        fontSize: (json['fontSize'] as num).toDouble(),
        fontFamily: json['fontFamily'] ?? "",
        color: Color(json['color']),
        customText: json['customText'] ?? "Your text",
        fontWeight: json['fontWeight'] != null ? FontWeight.values[json['fontWeight']] : FontWeight.normal,
        use24HourClock: json['use24HourClock'] ?? true,
        showSeconds: json['showSeconds'] ?? false,
        showDateWithClock: json['showDateWithClock'] ?? false,
      );
}
