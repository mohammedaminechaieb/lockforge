import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lock_widget.dart';
import '../services/live_data_service.dart';

/// Renders one lock-screen widget as text. Clock and date are always live;
/// the data-driven types show [live] values when given (preview) and
/// realistic placeholders otherwise (editor, gallery thumbnails) so
/// dragging things around never triggers network or sensor calls.
class CanvasWidgetRenderer extends StatefulWidget {
  final LockWidgetConfig config;
  final LiveValues? live;

  /// False for gallery thumbnails — dozens of per-second timers for tiny
  /// previews would be wasted work.
  final bool ticking;

  const CanvasWidgetRenderer({super.key, required this.config, this.live, this.ticking = true});

  @override
  State<CanvasWidgetRenderer> createState() => _CanvasWidgetRendererState();
}

class _CanvasWidgetRendererState extends State<CanvasWidgetRenderer> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant CanvasWidgetRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    final needsTimer = widget.ticking &&
        (widget.config.type == LockWidgetType.clock || widget.config.type == LockWidgetType.date);
    if (needsTimer && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
    } else if (!needsTimer) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _text() {
    final c = widget.config;
    final live = widget.live;
    return switch (c.type) {
      LockWidgetType.clock => formatClock(c, _now),
      LockWidgetType.date => formatDate(_now),
      LockWidgetType.text => c.customText,
      LockWidgetType.weather => live?.weather ?? 'Clear 21°C',
      LockWidgetType.steps => live?.steps ?? '4,231 steps',
      LockWidgetType.calendar => live?.calendar ?? 'Team sync · 14:00',
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final lines = _text().split('\n');
    // Clock + date: the date line is a caption under the time, not a
    // second giant line (dateLineSize mirrors the native overlay).
    if (c.type == LockWidgetType.clock && lines.length == 2) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [_line(lines[0], c.fontSize), _line(lines[1], dateLineSize(c.fontSize))],
      );
    }
    return _line(lines.join('\n'), c.fontSize);
  }

  Widget _line(String text, double size) {
    final c = widget.config;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: size,
        height: 1.15,
        color: c.color,
        fontFamily: c.fontFamily.isEmpty ? null : c.fontFamily,
        fontWeight: c.fontWeight,
        fontFeatures: c.type == LockWidgetType.clock ? const [FontFeature.tabularFigures()] : null,
        shadows: c.shadow
            ? [Shadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: size * 0.15, offset: const Offset(0, 1))]
            : null,
      ),
    );
  }
}

/// Same formatting as LockOverlayView.liveClockText on the native side —
/// keep the two in sync.
String formatClock(LockWidgetConfig c, DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  final String time;
  if (c.use24HourClock) {
    time = c.showSeconds ? '${two(now.hour)}:${two(now.minute)}:${two(now.second)}' : '${two(now.hour)}:${two(now.minute)}';
  } else {
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final suffix = now.hour >= 12 ? 'PM' : 'AM';
    time = c.showSeconds ? '$h:${two(now.minute)}:${two(now.second)} $suffix' : '$h:${two(now.minute)} $suffix';
  }
  return c.showDateWithClock ? '$time\n${formatDate(now)}' : time;
}

String formatDate(DateTime d) {
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}

/// Size of the date caption under a clock — keep in sync with LockOverlayView.
double dateLineSize(double clockSize) => (clockSize * 0.28).clamp(12.0, 40.0);
