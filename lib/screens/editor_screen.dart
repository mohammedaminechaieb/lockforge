import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import '../models/lock_widget.dart';
import '../models/theme_pack.dart';
import '../services/theme_io_service.dart';
import '../services/theme_storage_service.dart';
import '../services/wallpaper_service.dart';
import '../widgets/draggable_canvas_item.dart';
import 'lock_preview_screen.dart';
import 'widget_style_editor.dart';
import 'lock_screen_settings_screen.dart';

class EditorScreen extends StatefulWidget {
  final ThemePack theme;
  const EditorScreen({super.key, required this.theme});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late ThemePack theme;
  String? selectedWidgetId;
  final GlobalKey _canvasKey = GlobalKey();
  final _themeIo = ThemeIoService();
  final _storage = ThemeStorageService();
  final _uuid = const Uuid();

  Uint8List? _wallpaperBytes;
  bool _wallpaperLoading = false;

  @override
  void initState() {
    super.initState();
    theme = widget.theme;
    if (theme.useWallpaperBackground) _loadWallpaper();
  }

  Future<void> _loadWallpaper() async {
    setState(() => _wallpaperLoading = true);
    final bytes = await WallpaperService.fetchWallpaperBytes();
    if (!mounted) return;
    setState(() {
      _wallpaperBytes = bytes;
      _wallpaperLoading = false;
    });
  }

  /// Persists on every meaningful edit — not just on an explicit "Save"
  /// tap — since a StatefulWidget field alone (the previous version's
  /// approach) loses everything the moment this screen is popped or the
  /// app is killed in the background, which Android does constantly.
  Future<void> _persist() async {
    await _storage.upsert(theme);
  }

  void _addWidget(LockWidgetType type) {
    setState(() {
      final config = LockWidgetConfig(id: _uuid.v4(), type: type, xFraction: 0.5, yFraction: 0.5);
      if (type == LockWidgetType.clock) config.fontWeight = FontWeight.w200;
      theme.widgets.add(config);
    });
    _persist();
  }

  void _deleteSelected() {
    if (selectedWidgetId == null) return;
    setState(() {
      theme.widgets.removeWhere((w) => w.id == selectedWidgetId);
      selectedWidgetId = null;
    });
    _persist();
  }

  Future<void> _export() async {
    await _themeIo.exportTheme(theme);
  }

  Future<void> _import() async {
    final imported = await _themeIo.importTheme();
    if (imported != null) {
      setState(() => theme = imported);
      if (theme.useWallpaperBackground) _loadWallpaper();
      _persist();
    }
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: theme.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename theme'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      setState(() => theme.name = newName.trim());
      _persist();
    }
  }

  Future<void> _openBackgroundEditor() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Background', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Use device wallpaper'),
                subtitle: const Text('Shows your real wallpaper here and on the lock screen'),
                value: theme.useWallpaperBackground,
                onChanged: (v) {
                  setSheetState(() {});
                  setState(() => theme.useWallpaperBackground = v);
                  if (v) _loadWallpaper();
                  _persist();
                },
              ),
              if (!theme.useWallpaperBackground) ...[
                const SizedBox(height: 8),
                const Text('Background color', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    Colors.black,
                    Colors.white,
                    const Color(0xFF1B1B2F),
                    const Color(0xFF2C2C54),
                    const Color(0xFF0F3460),
                    const Color(0xFF16213E),
                  ].map((c) => GestureDetector(
                        onTap: () {
                          setSheetState(() {});
                          setState(() => theme.backgroundColor = c);
                          _persist();
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey, width: theme.backgroundColor == c ? 3 : 1),
                          ),
                        ),
                      )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = theme.widgets.firstWhereOrNull((w) => w.id == selectedWidgetId);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _rename,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(theme.name, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4),
              const Icon(Icons.edit, size: 16),
            ],
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.wallpaper), tooltip: 'Background', onPressed: _openBackgroundEditor),
          IconButton(icon: const Icon(Icons.lock), tooltip: 'Lock screen settings', onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => LockScreenSettingsScreen(theme: theme)));
          }),
          IconButton(icon: const Icon(Icons.play_arrow), tooltip: 'Preview', onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => LockPreviewScreen(theme: theme)));
          }),
          IconButton(icon: const Icon(Icons.file_upload), tooltip: 'Import theme', onPressed: _import),
          IconButton(icon: const Icon(Icons.file_download), tooltip: 'Export theme', onPressed: _export),
          if (selectedWidgetId != null)
            IconButton(icon: const Icon(Icons.delete), tooltip: 'Delete selected', onPressed: _deleteSelected),
        ],
      ),
      body: Column(
        children: [
          _palette(),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
              return Container(
                key: _canvasKey,
                width: canvasSize.width,
                height: canvasSize.height,
                color: theme.useWallpaperBackground ? Colors.black : theme.backgroundColor,
                child: Stack(
                  children: [
                    if (theme.useWallpaperBackground)
                      Positioned.fill(
                        child: _wallpaperBytes != null
                            ? Image.memory(_wallpaperBytes!, fit: BoxFit.cover)
                            : _wallpaperLoading
                                ? const Center(child: CircularProgressIndicator())
                                : Container(color: const Color(0xFF1B1B2F)), // fallback if wallpaper can't be read
                      ),
                    if (theme.useWallpaperBackground) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.15))),
                    ...theme.widgets.map((config) {
                      return DraggableCanvasItem(
                        key: ValueKey(config.id),
                        config: config,
                        canvasSize: canvasSize,
                        canvasKey: _canvasKey,
                        selected: config.id == selectedWidgetId,
                        onTap: () => setState(() => selectedWidgetId = config.id),
                        onPositionChanged: (x, y) {
                          setState(() {
                            config.xFraction = x;
                            config.yFraction = y;
                          });
                          _persist();
                        },
                      );
                    }),
                  ],
                ),
              );
            }),
          ),
          if (selected != null)
            WidgetStyleEditor(
              config: selected,
              onChanged: () {
                setState(() {});
                _persist();
              },
            ),
        ],
      ),
    );
  }

  Widget _palette() {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          _paletteButton('Clock', LockWidgetType.clock),
          _paletteButton('Weather', LockWidgetType.weather),
          _paletteButton('Steps', LockWidgetType.steps),
          _paletteButton('Calendar', LockWidgetType.calendar),
          _paletteButton('Text', LockWidgetType.text),
        ],
      ),
    );
  }

  Widget _paletteButton(String label, LockWidgetType type) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(label: Text('+ $label'), onPressed: () => _addWidget(type)),
    );
  }
}
