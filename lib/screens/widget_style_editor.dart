import 'package:flutter/material.dart';
import '../models/lock_widget.dart';

class WidgetStyleEditor extends StatelessWidget {
  final LockWidgetConfig config;
  final VoidCallback onChanged;

  const WidgetStyleEditor({super.key, required this.config, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surfaceVariant,
      constraints: const BoxConstraints(maxHeight: 320),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Editing: ${config.type.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                const Text('Size'),
                Expanded(
                  child: Slider(
                    min: 10,
                    max: 96,
                    value: config.fontSize,
                    onChanged: (v) {
                      config.fontSize = v;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            if (config.type == LockWidgetType.text)
              TextField(
                decoration: const InputDecoration(labelText: 'Custom text'),
                controller: TextEditingController(text: config.customText),
                onChanged: (v) {
                  config.customText = v;
                  onChanged();
                },
              ),
            if (config.type == LockWidgetType.clock) ...[
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('24-hour clock'),
                value: config.use24HourClock,
                onChanged: (v) {
                  config.use24HourClock = v;
                  onChanged();
                },
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Show seconds'),
                value: config.showSeconds,
                onChanged: (v) {
                  config.showSeconds = v;
                  onChanged();
                },
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Show date'),
                value: config.showDateWithClock,
                onChanged: (v) {
                  config.showDateWithClock = v;
                  onChanged();
                },
              ),
            ],
            const SizedBox(height: 8),
            const Text('Weight', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Wrap(
              spacing: 8,
              children: [
                (FontWeight.w200, 'Thin'),
                (FontWeight.normal, 'Regular'),
                (FontWeight.w600, 'Semibold'),
                (FontWeight.bold, 'Bold'),
              ].map((entry) {
                final (weight, label) = entry;
                final selected = config.fontWeight == weight;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    config.fontWeight = weight;
                    onChanged();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            const Text('Color', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Wrap(
              spacing: 8,
              children: [Colors.white, Colors.black, Colors.redAccent, Colors.cyanAccent, Colors.amber, Colors.purpleAccent]
                  .map((c) => GestureDetector(
                        onTap: () {
                          config.color = c;
                          onChanged();
                        },
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey, width: config.color == c ? 2 : 0.5),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
