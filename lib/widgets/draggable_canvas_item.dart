import 'package:flutter/material.dart';
import '../models/lock_widget.dart';
import 'canvas_widget_renderer.dart';

/// Wraps a CanvasWidgetRenderer so it can be dragged around the editor
/// canvas. Position updates are reported back as fractions (0..1) via
/// onPositionChanged so the layout stays resolution-independent.
class DraggableCanvasItem extends StatelessWidget {
  final LockWidgetConfig config;
  final Size canvasSize;
  final bool selected;
  final GlobalKey canvasKey;
  final VoidCallback onTap;
  final void Function(double xFraction, double yFraction) onPositionChanged;

  const DraggableCanvasItem({
    super.key,
    required this.config,
    required this.canvasSize,
    required this.selected,
    required this.canvasKey,
    required this.onTap,
    required this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final left = config.xFraction * canvasSize.width;
    final top = config.yFraction * canvasSize.height;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: onTap,
        child: Draggable(
          feedback: Material(color: Colors.transparent, child: _content()),
          childWhenDragging: Opacity(opacity: 0.3, child: _content()),
          onDragEnd: (details) {
            final canvasBox = canvasKey.currentContext?.findRenderObject() as RenderBox?;
            if (canvasBox == null) return;
            final local = canvasBox.globalToLocal(details.offset);
            final xFraction = (local.dx / canvasSize.width).clamp(0.0, 1.0);
            final yFraction = (local.dy / canvasSize.height).clamp(0.0, 1.0);
            onPositionChanged(xFraction, yFraction);
          },
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: selected
          ? BoxDecoration(border: Border.all(color: Colors.blueAccent, width: 1.5), borderRadius: BorderRadius.circular(4))
          : null,
      child: CanvasWidgetRenderer(config: config),
    );
  }
}
