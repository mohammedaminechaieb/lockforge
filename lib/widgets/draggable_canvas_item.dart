import 'package:flutter/material.dart';
import '../models/lock_widget.dart';
import 'canvas_widget_renderer.dart';
import 'theme_canvas.dart';

/// One widget on the editor canvas: tap to select, drag to move. The
/// widget follows the finger directly (no ghost copy) and snaps to the
/// canvas center lines, reported via [onSnapChanged] so guides can show.
class DraggableCanvasItem extends StatelessWidget {
  final LockWidgetConfig config;
  final Size canvasSize;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDragStart;
  final VoidCallback onMoved;
  final VoidCallback onDragEnd;
  final void Function(bool snapX, bool snapY) onSnapChanged;

  static const _snap = 0.015;

  const DraggableCanvasItem({
    super.key,
    required this.config,
    required this.canvasSize,
    required this.selected,
    required this.onTap,
    required this.onDragStart,
    required this.onMoved,
    required this.onDragEnd,
    required this.onSnapChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CenteredAt(
      config: config,
      canvasSize: canvasSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onPanStart: (_) {
          onTap();
          onDragStart();
        },
        onPanUpdate: (details) {
          // Raw (unsnapped) position is tracked separately so a widget can
          // be pulled back out of a snap instead of sticking to it.
          _raw ??= Offset(config.xFraction, config.yFraction);
          _raw = _raw! + Offset(details.delta.dx / canvasSize.width, details.delta.dy / canvasSize.height);
          var x = _raw!.dx.clamp(0.0, 1.0);
          var y = _raw!.dy.clamp(0.0, 1.0);
          final snapX = (x - 0.5).abs() < _snap;
          final snapY = (y - 0.5).abs() < _snap;
          if (snapX) x = 0.5;
          if (snapY) y = 0.5;
          config.xFraction = x;
          config.yFraction = y;
          onSnapChanged(snapX, snapY);
          onMoved();
        },
        onPanEnd: (_) {
          _raw = null;
          onSnapChanged(false, false);
          onDragEnd();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? Colors.lightBlueAccent : Colors.transparent, width: 2),
            borderRadius: BorderRadius.circular(8),
            color: selected ? Colors.lightBlueAccent.withValues(alpha: 0.08) : null,
          ),
          child: CanvasWidgetRenderer(config: config),
        ),
      ),
    );
  }
}

// Drag-session scratch state. Only one widget can be dragged at a time, so
// a single slot is enough and keeps the item itself stateless.
Offset? _raw;
