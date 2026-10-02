import 'dart:async';
import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../models/lock_widget.dart';
import '../models/theme_pack.dart';
import '../services/home_widget_service.dart';
import '../services/theme_io_service.dart';
import '../services/theme_storage_service.dart';
import '../services/wallpaper_service.dart';
import '../widgets/draggable_canvas_item.dart';
import '../widgets/theme_canvas.dart';
import 'lock_preview_screen.dart';
import 'lock_screen_settings_screen.dart';
import 'widget_style_editor.dart';

const _backgroundPalette = [
  Colors.black,
  Color(0xFF0B1026),
  Color(0xFF1B1B2F),
  Color(0xFF16213E),
  Color(0xFF0F3460),
  Color(0xFF1E3D32),
  Color(0xFF3E1F47),
  Color(0xFF4A1C1C),
  Color(0xFF37474F),
  Color(0xFFF5F5F5),
];

class EditorScreen extends StatefulWidget {
  final ThemePack theme;
  const EditorScreen({super.key, required this.theme});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late ThemePack theme = widget.theme;
  String? selectedWidgetId;
  final _themeIo = ThemeIoService();
  final _storage = ThemeStorageService();

  Uint8List? _wallpaperBytes;
  Timer? _saveDebounce;
  bool _snapX = false;
  bool _snapY = false;

  final List<ThemePack> _undo = [];
  final List<ThemePack> _redo = [];

  @override
  void initState() {
    super.initState();
    WallpaperService.fetchWallpaperBytes().then((bytes) {
      if (mounted) setState(() => _wallpaperBytes = bytes);
    });
  }

  @override
  void dispose() {
    // Flush any pending save so the last edit is never lost on back.
    if (_saveDebounce?.isActive ?? false) {
      _saveDebounce!.cancel();
      _persistNow();
    }
    super.dispose();
  }

  // ---- Persistence ----------------------------------------------------

  /// Debounced so dragging a slider doesn't rewrite storage 60x a second.
  void _persist() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), _persistNow);
  }

  Future<void> _persistNow() async {
    await _storage.upsert(theme);
    // Keep the real lock screen in sync while editing the active theme.
    if (await _storage.getActiveId() == theme.id) {
      await HomeWidgetService.pushTheme(theme);
    }
  }

  // ---- Undo / redo ----------------------------------------------------

  void _recordUndo() {
    _undo.add(theme.snapshot());
    if (_undo.length > 50) _undo.removeAt(0);
    _redo.clear();
  }

  void _restore(List<ThemePack> from, List<ThemePack> to) {
    if (from.isEmpty) return;
    to.add(theme.snapshot());
    setState(() {
      theme = from.removeLast();
      if (theme.widgets.none((w) => w.id == selectedWidgetId)) selectedWidgetId = null;
    });
    _persist();
  }

  // ---- Widget operations ----------------------------------------------

  void _addWidget(LockWidgetType type) {
    _recordUndo();
    // Drop new widgets just below the lowest existing one so they don't
    // stack invisibly on top of each other in the middle of the screen.
    final lowest = theme.widgets.map((w) => w.yFraction).maxOrNull;
    final y = lowest == null ? 0.3 : (lowest + 0.08).clamp(0.05, 0.95);
    final config = LockWidgetConfig(
      type: type,
      xFraction: 0.5,
      yFraction: y,
      fontSize: switch (type) { LockWidgetType.clock => 64, LockWidgetType.date => 18, _ => 20 },
      fontWeight: type == LockWidgetType.clock ? FontWeight.w200 : FontWeight.normal,
    );
    setState(() {
      theme.widgets.add(config);
      selectedWidgetId = config.id;
    });
    _persist();
  }

  void _deleteSelected() {
    _recordUndo();
    setState(() {
      theme.widgets.removeWhere((w) => w.id == selectedWidgetId);
      selectedWidgetId = null;
    });
    _persist();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Widget deleted'),
        action: SnackBarAction(label: 'Undo', onPressed: () => _restore(_undo, _redo)),
      ));
  }

  void _duplicateSelected() {
    final selected = theme.widgets.firstWhereOrNull((w) => w.id == selectedWidgetId);
    if (selected == null) return;
    _recordUndo();
    final copy = selected.copyWith(yFraction: (selected.yFraction + 0.06).clamp(0.0, 1.0));
    setState(() {
      theme.widgets.add(copy);
      selectedWidgetId = copy.id;
    });
    _persist();
  }

  // ---- Theme-level actions --------------------------------------------

  Future<void> _rename() async {
    final controller = TextEditingController(text: theme.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename theme'),
        content: TextField(controller: controller, autofocus: true, onSubmitted: (v) => Navigator.of(context).pop(v)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      setState(() => theme.name = newName.trim());
      _persist();
    }
  }

  Future<void> _openBackgroundEditor() async {
    _recordUndo();
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          void update(VoidCallback fn) {
            setSheetState(fn);
            setState(() {});
            _persist();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Background', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  SegmentedButton<BackgroundType>(
                    segments: const [
                      ButtonSegment(value: BackgroundType.wallpaper, icon: Icon(Icons.wallpaper), label: Text('Wallpaper')),
                      ButtonSegment(value: BackgroundType.color, icon: Icon(Icons.palette_outlined), label: Text('Color')),
                      ButtonSegment(value: BackgroundType.image, icon: Icon(Icons.photo_outlined), label: Text('Photo')),
                    ],
                    selected: {theme.backgroundType},
                    onSelectionChanged: (s) async {
                      final type = s.first;
                      if (type == BackgroundType.image && theme.backgroundImagePath == null) {
                        final path = await _themeIo.pickBackgroundImage();
                        if (path == null) return;
                        update(() => theme.backgroundImagePath = path);
                      }
                      update(() => theme.backgroundType = type);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (theme.backgroundType == BackgroundType.wallpaper)
                    Text(
                      _wallpaperBytes == null
                          ? 'Your current wallpaper will show behind the design on the real lock screen. '
                              '(Android doesn\'t let apps read it on this device, so the editor shows a placeholder.)'
                          : 'Uses your current wallpaper — change it in system settings and the lock screen follows.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (theme.backgroundType == BackgroundType.image)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose a different photo'),
                      onPressed: () async {
                        final path = await _themeIo.pickBackgroundImage();
                        if (path != null) update(() => theme.backgroundImagePath = path);
                      },
                    ),
                  if (theme.backgroundType == BackgroundType.color)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _backgroundPalette.map((c) {
                        final selected = theme.backgroundColor.toARGB32() == c.toARGB32();
                        return GestureDetector(
                          onTap: () => update(() => theme.backgroundColor = c),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? Theme.of(context).colorScheme.primary : Colors.white24,
                                width: selected ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  if (theme.backgroundType != BackgroundType.color) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Dim'),
                        Expanded(
                          child: Slider(
                            value: theme.dim,
                            max: 0.8,
                            onChanged: (v) => update(() => theme.dim = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _export() async {
    await _persistNow();
    await _themeIo.exportTheme(theme);
  }

  // ---- UI -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final selected = theme.widgets.firstWhereOrNull((w) => w.id == selectedWidgetId);
    final canvasSize = deviceCanvasSize(context);

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _rename,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(theme.name, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined, size: 16),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _undo.isEmpty ? null : () => _restore(_undo, _redo),
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
            onPressed: _redo.isEmpty ? null : () => _restore(_redo, _undo),
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Live preview',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LockPreviewScreen(theme: theme))),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'lock':
                  await _persistNow();
                  if (!context.mounted) return;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => LockScreenSettingsScreen(theme: theme)));
                case 'export':
                  _export();
                case 'rename':
                  _rename();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'lock', child: ListTile(leading: Icon(Icons.lock_outline), title: Text('Use as lock screen'))),
              PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.ios_share), title: Text('Share / export'))),
              PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Rename'))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Center(
                child: AspectRatio(
                  aspectRatio: canvasSize.width / canvasSize.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      // The design is laid out at full phone size and scaled
                      // down here, so text sizes match the real lock screen.
                      child: FittedBox(child: _canvas(canvasSize)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (selected != null)
            WidgetStyleEditor(
              key: ValueKey(selected.id),
              config: selected,
              onBeforeChange: _recordUndo,
              onChanged: () {
                setState(() {});
                _persist();
              },
              onDuplicate: _duplicateSelected,
              onDelete: _deleteSelected,
              onClose: () => setState(() => selectedWidgetId = null),
            )
          else
            _addBar(),
        ],
      ),
    );
  }

  Widget _canvas(Size canvasSize) {
    return SizedBox.fromSize(
      size: canvasSize,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => selectedWidgetId = null), // tap empty space to deselect
              child: ThemeBackground(theme: theme, wallpaperBytes: _wallpaperBytes),
            ),
          ),
          if (theme.widgets.isEmpty)
            const Center(
              child: Text('Add a widget from the bar below',
                  style: TextStyle(color: Colors.white70, fontSize: 18)),
            ),
          if (_snapX) Positioned(left: canvasSize.width / 2 - 1, top: 0, bottom: 0, child: Container(width: 2, color: Colors.pinkAccent)),
          if (_snapY) Positioned(top: canvasSize.height / 2 - 1, left: 0, right: 0, child: Container(height: 2, color: Colors.pinkAccent)),
          for (final config in theme.widgets)
            DraggableCanvasItem(
              key: ValueKey(config.id),
              config: config,
              canvasSize: canvasSize,
              selected: config.id == selectedWidgetId,
              onTap: () => setState(() => selectedWidgetId = config.id),
              onDragStart: _recordUndo,
              onMoved: () => setState(() {}),
              onDragEnd: _persist,
              onSnapChanged: (x, y) {
                if (x != _snapX || y != _snapY) setState(() { _snapX = x; _snapY = y; });
              },
            ),
        ],
      ),
    );
  }

  Widget _addBar() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tap a widget to style it · drag to move', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _addButton(Icons.wallpaper, 'Background', _openBackgroundEditor, highlight: true),
                    for (final type in LockWidgetType.values) _addButton(type.icon, type.label, () => _addWidget(type)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addButton(IconData icon, String label, VoidCallback onTap, {bool highlight = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 78,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: highlight ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                child: Icon(icon, color: highlight ? scheme.onPrimaryContainer : scheme.onSurface),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
