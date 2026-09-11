import 'package:flutter/material.dart';
import '../models/theme_pack.dart';
import '../models/starter_themes.dart';
import '../services/theme_storage_service.dart';
import 'editor_screen.dart';

class ThemeGalleryScreen extends StatefulWidget {
  const ThemeGalleryScreen({super.key});

  @override
  State<ThemeGalleryScreen> createState() => _ThemeGalleryScreenState();
}

class _ThemeGalleryScreenState extends State<ThemeGalleryScreen> {
  final _storage = ThemeStorageService();
  List<ThemePack> _themes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final themes = await _storage.loadAll();
    setState(() {
      _themes = themes;
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
      builder: (context) => _StarterPicker(),
    );
    if (picked != null) {
      await _storage.upsert(picked);
      _openEditor(picked);
    }
  }

  Future<void> _duplicate(ThemePack theme) async {
    final copy = theme.copyWith(name: '${theme.name} copy');
    await _storage.upsert(copy);
    _load();
  }

  Future<void> _delete(ThemePack theme) async {
    await _storage.delete(theme.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your lock screen themes')),
      floatingActionButton: FloatingActionButton(onPressed: _createNew, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _themes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No themes yet.'),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _createNew, child: const Text('Create your first theme')),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: _themes.length,
                  itemBuilder: (context, index) {
                    final theme = _themes[index];
                    return _ThemeCard(
                      theme: theme,
                      onTap: () => _openEditor(theme),
                      onDuplicate: () => _duplicate(theme),
                      onDelete: () => _delete(theme),
                    );
                  },
                ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final ThemePack theme;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _ThemeCard({required this.theme, required this.onTap, required this.onDuplicate, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: theme.useWallpaperBackground ? Colors.grey.shade800 : theme.backgroundColor,
                alignment: Alignment.center,
                child: theme.useWallpaperBackground
                    ? const Icon(Icons.wallpaper, color: Colors.white54, size: 32)
                    : Icon(Icons.palette, color: theme.backgroundColor.computeLuminance() > 0.5 ? Colors.black26 : Colors.white24, size: 32),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(theme.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'duplicate') onDuplicate();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
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
  @override
  Widget build(BuildContext context) {
    final starters = StarterThemes.all();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Start from a template', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          ...starters.map((s) => ListTile(
                leading: const Icon(Icons.dashboard_customize),
                title: Text(s.name),
                subtitle: Text('${s.widgets.length} widget${s.widgets.length == 1 ? '' : 's'}'),
                onTap: () => Navigator.of(context).pop(s),
              )),
          ListTile(
            leading: const Icon(Icons.crop_free),
            title: const Text('Blank canvas'),
            onTap: () => Navigator.of(context).pop(ThemePack(name: 'New Theme', widgets: [])),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
