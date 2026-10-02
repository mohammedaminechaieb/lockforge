import 'package:flutter/material.dart';
import '../models/lock_widget.dart';

const lockPalette = [
  Colors.white,
  Color(0xFFBDBDBD),
  Color(0xFF212121),
  Color(0xFFFF5252),
  Color(0xFFFF9100),
  Color(0xFFFFD740),
  Color(0xFFB2FF59),
  Color(0xFF64FFDA),
  Color(0xFF18FFFF),
  Color(0xFF448AFF),
  Color(0xFF8C9EFF),
  Color(0xFFE040FB),
  Color(0xFFFF80AB),
];

/// Bottom panel for the selected widget. Stateful so the text field keeps
/// one controller per widget — rebuilding a controller on every keystroke
/// (the old version) made the cursor jump back to the start.
class WidgetStyleEditor extends StatefulWidget {
  final LockWidgetConfig config;

  /// Called right before a change, so the editor can record an undo step.
  final VoidCallback onBeforeChange;
  final VoidCallback onChanged;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const WidgetStyleEditor({
    super.key,
    required this.config,
    required this.onBeforeChange,
    required this.onChanged,
    required this.onDuplicate,
    required this.onDelete,
    required this.onClose,
  });

  @override
  State<WidgetStyleEditor> createState() => _WidgetStyleEditorState();
}

class _WidgetStyleEditorState extends State<WidgetStyleEditor> {
  late final TextEditingController _text = TextEditingController(text: widget.config.customText);
  bool _textUndoRecorded = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _change(void Function(LockWidgetConfig c) apply) {
    widget.onBeforeChange();
    apply(widget.config);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(c.type.icon, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(c.type.label, style: Theme.of(context).textTheme.titleMedium)),
                    IconButton(
                      tooltip: 'Center horizontally',
                      icon: const Icon(Icons.align_horizontal_center),
                      onPressed: () => _change((c) => c.xFraction = 0.5),
                    ),
                    IconButton(tooltip: 'Duplicate', icon: const Icon(Icons.copy_all_outlined), onPressed: widget.onDuplicate),
                    IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: widget.onDelete),
                    IconButton(tooltip: 'Done', icon: const Icon(Icons.check), onPressed: widget.onClose),
                  ],
                ),
                if (c.type == LockWidgetType.text)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                    child: TextField(
                      controller: _text,
                      decoration: const InputDecoration(labelText: 'Text', border: OutlineInputBorder(), isDense: true),
                      onChanged: (v) {
                        // One undo step per editing session, not per keystroke.
                        if (!_textUndoRecorded) {
                          widget.onBeforeChange();
                          _textUndoRecorded = true;
                        }
                        c.customText = v;
                        widget.onChanged();
                      },
                    ),
                  ),
                Row(
                  children: [
                    const SizedBox(width: 44, child: Text('Size')),
                    Expanded(
                      child: Slider(
                        min: 10,
                        max: 140,
                        value: c.fontSize.clamp(10, 140),
                        onChangeStart: (_) => widget.onBeforeChange(),
                        onChanged: (v) {
                          c.fontSize = v.roundToDouble();
                          widget.onChanged();
                        },
                      ),
                    ),
                    SizedBox(width: 32, child: Text('${c.fontSize.round()}', textAlign: TextAlign.end)),
                    const SizedBox(width: 8),
                  ],
                ),
                if (c.type == LockWidgetType.clock)
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(label: const Text('24-hour'), selected: c.use24HourClock, onSelected: (v) => _change((c) => c.use24HourClock = v)),
                      FilterChip(label: const Text('Seconds'), selected: c.showSeconds, onSelected: (v) => _change((c) => c.showSeconds = v)),
                      FilterChip(label: const Text('Date'), selected: c.showDateWithClock, onSelected: (v) => _change((c) => c.showDateWithClock = v)),
                    ],
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final (weight, label) in lockFontWeights)
                      ChoiceChip(
                        label: Text(label, style: TextStyle(fontWeight: weight)),
                        selected: c.fontWeight == weight,
                        onSelected: (_) => _change((c) => c.fontWeight = weight),
                      ),
                    FilterChip(
                      avatar: const Icon(Icons.blur_on, size: 18),
                      label: const Text('Shadow'),
                      selected: c.shadow,
                      onSelected: (v) => _change((c) => c.shadow = v),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final color in lockPalette)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _change((c) => c.color = color),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: c.color.toARGB32() == color.toARGB32() ? scheme.primary : Colors.white24,
                                  width: c.color.toARGB32() == color.toARGB32() ? 3 : 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
