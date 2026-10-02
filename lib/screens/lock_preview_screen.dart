import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/theme_pack.dart';
import '../services/live_data_service.dart';
import '../services/wallpaper_service.dart';
import '../widgets/theme_canvas.dart';

/// Full-screen render of a ThemePack with real live data (weather, steps,
/// next event) — "what it will actually look like". Tap anywhere to close.
class LockPreviewScreen extends StatefulWidget {
  final ThemePack theme;
  const LockPreviewScreen({super.key, required this.theme});

  @override
  State<LockPreviewScreen> createState() => _LockPreviewScreenState();
}

class _LockPreviewScreenState extends State<LockPreviewScreen> {
  Uint8List? _wallpaperBytes;
  LiveValues? _live;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WallpaperService.fetchWallpaperBytes().then((b) {
      if (mounted) setState(() => _wallpaperBytes = b);
    });
    final use24h = widget.theme.widgets.firstOrNull?.use24HourClock ?? true;
    LiveDataService.fetch(use24h: use24h).then((v) {
      if (mounted) setState(() => _live = v);
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: ThemeCanvas(
                  theme: widget.theme,
                  canvasSize: deviceCanvasSize(context),
                  wallpaperBytes: _wallpaperBytes,
                  live: _live ?? const LiveValues(weather: 'Loading…', steps: '…', calendar: 'Loading…'),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Text('Tap anywhere to close', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
