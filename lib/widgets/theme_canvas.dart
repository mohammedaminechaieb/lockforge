import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/lock_widget.dart';
import '../models/theme_pack.dart';
import '../services/live_data_service.dart';
import 'canvas_widget_renderer.dart';

/// Fallback when the real wallpaper can't be read (Android 13+ restricts
/// it): a soft gradient that reads as "your wallpaper goes here".
const _wallpaperFallback = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF3A2D6B), Color(0xFF1B3B5A), Color(0xFF0E1A2B)],
);

/// The theme's backdrop: wallpaper, flat color or photo, plus its dim scrim.
class ThemeBackground extends StatelessWidget {
  final ThemePack theme;
  final Uint8List? wallpaperBytes;
  const ThemeBackground({super.key, required this.theme, this.wallpaperBytes});

  @override
  Widget build(BuildContext context) {
    final Widget base;
    switch (theme.backgroundType) {
      case BackgroundType.wallpaper:
        base = wallpaperBytes != null
            ? Image.memory(wallpaperBytes!, fit: BoxFit.cover, gaplessPlayback: true)
            : const DecoratedBox(decoration: BoxDecoration(gradient: _wallpaperFallback));
      case BackgroundType.image:
        final path = theme.backgroundImagePath;
        base = path != null && File(path).existsSync()
            ? Image.file(File(path), fit: BoxFit.cover, gaplessPlayback: true)
            : const DecoratedBox(decoration: BoxDecoration(gradient: _wallpaperFallback));
      case BackgroundType.color:
        base = ColoredBox(color: theme.backgroundColor);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        if (theme.backgroundType != BackgroundType.color && theme.dim > 0)
          ColoredBox(color: Colors.black.withValues(alpha: theme.dim)),
      ],
    );
  }
}

/// A read-only render of a whole design at a virtual [canvasSize] (normally
/// the phone's screen size). Wrap in a FittedBox to show it smaller — text
/// scales with it, so thumbnails are faithful miniatures.
class ThemeCanvas extends StatelessWidget {
  final ThemePack theme;
  final Size canvasSize;
  final Uint8List? wallpaperBytes;
  final LiveValues? live;
  final bool ticking;

  const ThemeCanvas({
    super.key,
    required this.theme,
    required this.canvasSize,
    this.wallpaperBytes,
    this.live,
    this.ticking = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: canvasSize,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: ThemeBackground(theme: theme, wallpaperBytes: wallpaperBytes)),
          for (final config in theme.widgets)
            CenteredAt(
              config: config,
              canvasSize: canvasSize,
              child: CanvasWidgetRenderer(config: config, live: live, ticking: ticking),
            ),
        ],
      ),
    );
  }
}

/// Positions [child] so its CENTER sits at the config's (x, y) fraction —
/// the anchor shared with the native lock screen overlay.
class CenteredAt extends StatelessWidget {
  final LockWidgetConfig config;
  final Size canvasSize;
  final Widget child;
  const CenteredAt({super.key, required this.config, required this.canvasSize, required this.child});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: config.xFraction * canvasSize.width,
      top: config.yFraction * canvasSize.height,
      child: FractionalTranslation(translation: const Offset(-0.5, -0.5), child: child),
    );
  }
}

/// The phone's full screen size in logical pixels — the coordinate space
/// designs are laid out in, regardless of how big the editor canvas is.
Size deviceCanvasSize(BuildContext context) {
  final view = View.of(context);
  final size = view.physicalSize / view.devicePixelRatio;
  return size.shortestSide > 0 ? Size(size.shortestSide, size.longestSide) : const Size(392, 850);
}
