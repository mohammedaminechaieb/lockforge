import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/starter_themes.dart';
import '../models/theme_pack.dart';
import '../services/home_widget_service.dart';
import '../services/live_data_service.dart';
import '../services/lock_overlay_bridge.dart';
import '../services/theme_io_service.dart';
import '../services/theme_storage_service.dart';
import '../services/wallpaper_service.dart';
import '../widgets/theme_canvas.dart';
import 'editor_screen.dart';

class ThemeGalleryScreen extends StatefulWidget {
  const ThemeGalleryScreen({super.key});

  @override
  State<ThemeGalleryScreen> createState() => _ThemeGalleryScreenState();
}

class _ThemeGalleryScreenState extends State<ThemeGalleryScreen> {
  final _storage = ThemeStorageService();
  final _io = ThemeIoService();
  List<ThemePack> _themes = [];
  String? _activeId;
  bool _overlayOn = false;
  bool _loading = true;
  Uint8List? _wallpaper;

  @override
  void initState() {
    super.initState();
    _load();
    WallpaperService.fetchWallpaperBytes().then((b) {
      if (mounted) setState(() => _wallpaper = b);
    });
    _refreshLockScreenData();
  }

  /// The native lock screen can't fetch weather/steps/calendar itself, so
  /// every app launch refreshes them for the active theme.
  Future<void> _refreshLockScreenData() async {
    final activeId = await _storage.getActiveId();
    if (activeId == null || !await LockOverlayBridge.isEnabled()) return;
    final themes = await _storage.loadAll();
    final active = themes.where((t) => t.id == activeId).firstOrNull;
    if (active == null) return;
    await HomeWidgetService.pushAll(active, await LiveDataService.fetch());
  }

  Future<void> _load() async {
    final themes = await _storage.loadAll();
    final activeId = await _storage.getActiveId();
    final overlayOn = await LockOverlayBridge.isEnabled().catchError((_) => false);
    if (!mounted) return;
    setState(() {
      _themes = themes;
      _activeId = activeId;
      _overlayOn = overlayOn;
      _loading = false;
    });
  }

  Future<void> _openEditor(ThemePack theme) async {
    await _storage.setLastOpened(theme.id);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorScreen(theme: theme)));
    _load(); // picks up whatever the editor auto-saved while it was open
  }

  Future<void> _createNew() async {
    final picked = await showModalBottomSheet<ThemePack>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _StarterPicker(wallpaper: _wallpaper),
    );
    if (picked != null) {
      await _storage.upsert(picked);
      _openEditor(picked);
    }
  }

  Future<void> _import() async {
    try {
      final theme = await _io.importTheme();
      if (theme == null) return;
      await _storage.upsert(theme);
      await _load();
      _snack('Imported "${theme.name}"');
    } on FormatException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _duplicate(ThemePack theme) async {
    await _storage.upsert(theme.copyWith(name: '${theme.name} copy'));
    _load();
  }

  Future<void> _delete(ThemePack theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${theme.name}"?'),
        content: Text(theme.id == _activeId ? 'This theme is your lock screen — the custom lock screen will show nothing until you pick another.' : 'This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _storage.delete(theme.id);
    _load();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LockForge'),
        actions: [
          IconButton(icon: const Icon(Icons.file_open_outlined), tooltip: 'Import a theme file', onPressed: _import),
        ],
      ),
      floatingActionButton: _themes.isEmpty
          ? null
          : FloatingActionButton.extended(onPressed: _createNew, icon: const Icon(Icons.add), label: const Text('New theme')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _themes.isEmpty
              ? _emptyState()
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
                    childAspectRatio: 0.52,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: _themes.length,
                  itemBuilder: (context, index) {
                    final theme = _themes[index];
                    return _ThemeCard(
                      theme: theme,
                      wallpaper: _wallpaper,
                      isActive: _overlayOn && theme.id == _activeId,
                      onTap: () => _openEditor(theme),
                      onDuplicate: () => _duplicate(theme),
                      onExport: () => _io.exportTheme(theme),
                      onDelete: () => _delete(theme),
                    );
                  },
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_android, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Design your lock screen', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Pick a template, drag widgets where you want them, then set it as your lock screen.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _createNew, icon: const Icon(Icons.add), label: const Text('Create your first theme')),
            TextButton(onPressed: _import, child: const Text('or import a theme file')),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final ThemePack theme;
  final Uint8List? wallpaper;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  const _ThemeCard({
    required this.theme,
    required this.wallpaper,
    required this.isActive,
    required this.onTap,
    required this.onDuplicate,
    required this.onExport,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isActive ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FittedBox(
                    fit: BoxFit.cover,
                    child: ThemeCanvas(theme: theme, canvasSize: deviceCanvasSize(context), wallpaperBytes: wallpaper, ticking: false),
                  ),
                  if (isActive)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Chip(
                        avatar: const Icon(Icons.lock, size: 14),
                        label: const Text('Lock screen'),
                        visualDensity: VisualDensity.compact,
                        labelStyle: const TextStyle(fontSize: 11),
                        backgroundColor: scheme.primaryContainer,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Expanded(child: Text(theme.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'duplicate':
                          onDuplicate();
                        case 'export':
                          onExport();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'duplicate', child: ListTile(leading: Icon(Icons.copy_all_outlined), title: Text('Duplicate'))),
                      PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.ios_share), title: Text('Share'))),
                      PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarterPicker extends StatelessWidget {
  final Uint8List? wallpaper;
  const _StarterPicker({required this.wallpaper});

  @override
  Widget build(BuildContext context) {
    final starters = [...StarterThemes.all(), ThemePack(name: 'Blank canvas')];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Start from a template', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: starters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final s = starters[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).pop(s),
                    child: SizedBox(
                      width: 120,
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: ThemeCanvas(theme: s, canvasSize: deviceCanvasSize(context), wallpaperBytes: wallpaper, ticking: false),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
