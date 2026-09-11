import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/theme_pack.dart';
import '../widgets/canvas_widget_renderer.dart';
import '../services/weather_service.dart';
import '../services/calendar_service.dart';
import '../services/home_widget_service.dart';
import '../services/wallpaper_service.dart';

/// Read-only, full-screen render of a ThemePack with live data flowing —
/// this is "what it would actually look like" as opposed to the editor's
/// placeholder values (kept cheap so dragging around the canvas doesn't
/// spam network/sensor calls). Also pushes the same live data out to the
/// native home-screen widget (see native_widget_snippets/android/) each
/// time this screen opens, so opening the preview is what keeps the
/// real widget's numbers current.
class LockPreviewScreen extends StatefulWidget {
  final ThemePack theme;
  const LockPreviewScreen({super.key, required this.theme});

  @override
  State<LockPreviewScreen> createState() => _LockPreviewScreenState();
}

class _LockPreviewScreenState extends State<LockPreviewScreen> {
  Uint8List? _wallpaperBytes;

  @override
  void initState() {
    super.initState();
    _pushWidgetState();
    if (widget.theme.useWallpaperBackground) _loadWallpaper();
  }

  Future<void> _loadWallpaper() async {
    final bytes = await WallpaperService.fetchWallpaperBytes();
    if (mounted) setState(() => _wallpaperBytes = bytes);
  }

  Future<void> _pushWidgetState() async {
    final now = DateTime.now();
    final timeLabel = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final event = await CalendarService().fetchNextEvent();
    final eventLabel = event == null
        ? 'No events today'
        : '${event.title} \u00b7 ${TimeOfDay.fromDateTime(event.start).format(context)}';

    final weather = await WeatherService().fetchCurrent();
    final weatherLabel = weather == null ? '' : '${weather.condition} ${weather.tempCelsius.round()}\u00b0C';

    await HomeWidgetService.pushState(
      timeLabel: timeLabel,
      eventLabel: eventLabel,
      weatherLabel: weatherLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Scaffold(
      backgroundColor: theme.useWallpaperBackground ? Colors.black : theme.backgroundColor,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: LayoutBuilder(builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            children: [
              if (theme.useWallpaperBackground)
                Positioned.fill(
                  child: _wallpaperBytes != null
                      ? Image.memory(_wallpaperBytes!, fit: BoxFit.cover)
                      : Container(color: const Color(0xFF1B1B2F)),
                ),
              if (theme.useWallpaperBackground) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.15))),
              ...theme.widgets.map((config) {
                return Positioned(
                  left: config.xFraction * size.width,
                  top: config.yFraction * size.height,
                  child: CanvasWidgetRenderer(config: config, liveData: true),
                );
              }),
            ],
          );
        }),
      ),
    );
  }
}
