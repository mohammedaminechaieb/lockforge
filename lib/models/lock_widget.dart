import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum LockWidgetType { clock, date, weather, steps, calendar, text }

extension LockWidgetTypeInfo on LockWidgetType {
  String get label => switch (this) {
        LockWidgetType.clock => 'Clock',
        LockWidgetType.date => 'Date',
        LockWidgetType.weather => 'Weather',
        LockWidgetType.steps => 'Steps',
        LockWidgetType.calendar => 'Next event',
        LockWidgetType.text => 'Text',
      };

  IconData get icon => switch (this) {
        LockWidgetType.clock => Icons.schedule,
        LockWidgetType.date => Icons.today,
        LockWidgetType.weather => Icons.wb_sunny_outlined,
        LockWidgetType.steps => Icons.directions_walk,
        LockWidgetType.calendar => Icons.event,
        LockWidgetType.text => Icons.text_fields,
      };
}

/// The font weights offered in the editor, in the order they're stored.
/// Stored as a plain 100..900 number so the native overlay can use it directly.
const lockFontWeights = [
  (FontWeight.w200, 'Thin'),
  (FontWeight.w400, 'Regular'),
  (FontWeight.w600, 'Semibold'),
  (FontWeight.w700, 'Bold'),
];

/// One element on the lock screen canvas.
///
/// [xFraction]/[yFraction] are the widget's CENTER as a fraction (0..1) of
/// the canvas — the same anchor the native overlay draws from — so a
/// layout looks identical in the editor, the preview and on the real lock
/// screen, on any device size.
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

  /// Soft drop shadow that keeps text legible over busy wallpapers/photos.
  bool shadow;

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
    this.shadow = true,
    this.use24HourClock = true,
    this.showSeconds = false,
    this.showDateWithClock = false,
  }) : id = id ?? const Uuid().v4();

  /// A copy with a fresh id (used for duplicating and for theme copies).
  LockWidgetConfig copyWith({double? xFraction, double? yFraction}) => LockWidgetConfig.fromJson({
        ...toJson(),
        'id': const Uuid().v4(),
        if (xFraction != null) 'x': xFraction,
        if (yFraction != null) 'y': yFraction,
      });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': xFraction,
        'y': yFraction,
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'color': color.toARGB32(),
        'customText': customText,
        'fontWeightValue': fontWeight.value,
        'shadow': shadow,
        'use24HourClock': use24HourClock,
        'showSeconds': showSeconds,
        'showDateWithClock': showDateWithClock,
      };

  factory LockWidgetConfig.fromJson(Map<String, dynamic> json) => LockWidgetConfig(
        id: json['id'],
        type: LockWidgetType.values.asNameMap()[json['type']] ?? LockWidgetType.text,
        xFraction: (json['x'] as num).toDouble(),
        yFraction: (json['y'] as num).toDouble(),
        fontSize: (json['fontSize'] as num).toDouble(),
        fontFamily: json['fontFamily'] ?? "",
        color: Color(json['color']),
        customText: json['customText'] ?? "Your text",
        fontWeight: _readWeight(json),
        shadow: json['shadow'] ?? true,
        use24HourClock: json['use24HourClock'] ?? true,
        showSeconds: json['showSeconds'] ?? false,
        showDateWithClock: json['showDateWithClock'] ?? false,
      );

  static FontWeight _readWeight(Map<String, dynamic> json) {
    final value = json['fontWeightValue'];
    if (value is int) {
      return FontWeight.values.firstWhere((w) => w.value == value, orElse: () => FontWeight.normal);
    }
    // Older saves stored FontWeight.index (0 = w100 … 8 = w900).
    final index = json['fontWeight'];
    if (index is int && index >= 0 && index < FontWeight.values.length) return FontWeight.values[index];
    return FontWeight.normal;
  }
}
