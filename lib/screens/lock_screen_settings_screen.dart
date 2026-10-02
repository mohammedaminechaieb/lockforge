import 'package:flutter/material.dart';
import '../models/theme_pack.dart';
import '../services/home_widget_service.dart';
import '../services/live_data_service.dart';
import '../services/lock_overlay_bridge.dart';
import '../services/theme_storage_service.dart';

/// Turns the real wake-screen overlay on/off for this theme, walks the
/// user through the permissions it needs, and refreshes its live data.
class LockScreenSettingsScreen extends StatefulWidget {
  final ThemePack theme;
  const LockScreenSettingsScreen({super.key, required this.theme});

  @override
  State<LockScreenSettingsScreen> createState() => _LockScreenSettingsScreenState();
}

class _LockScreenSettingsScreenState extends State<LockScreenSettingsScreen> with WidgetsBindingObserver {
  final _storage = ThemeStorageService();
  bool _enabled = false;
  bool _isActiveTheme = false;
  bool _overlayOk = false;
  bool _notificationsOk = false;
  bool _loading = true;
  bool _busy = false;
  String _status = '';

  bool get _ready => _overlayOk && _notificationsOk;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-check permissions when coming back from the system settings screens.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final enabled = await LockOverlayBridge.isEnabled();
    final overlayOk = await LockOverlayBridge.canDrawOverlays();
    final notificationsOk = await LockOverlayBridge.hasNotificationPermission();
    final activeId = await _storage.getActiveId();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _overlayOk = overlayOk;
      _notificationsOk = notificationsOk;
      _isActiveTheme = activeId == widget.theme.id;
      _loading = false;
    });
  }

  Future<void> _activate() async {
    setState(() => _busy = true);
    await _storage.setActiveId(widget.theme.id);
    await _push();
    await LockOverlayBridge.setEnabled(true);
    await _load();
    setState(() => _busy = false);
  }

  Future<void> _turnOff() async {
    await LockOverlayBridge.setEnabled(false);
    await _load();
    setState(() => _status = 'Custom lock screen turned off.');
  }

  Future<void> _push() async {
    setState(() => _status = 'Fetching weather, steps and calendar…');
    final use24h = widget.theme.widgets.firstOrNull?.use24HourClock ?? true;
    final live = await LiveDataService.fetch(use24h: use24h);
    await HomeWidgetService.pushAll(widget.theme, live);
    if (mounted) setState(() => _status = 'Up to date · shows the next time your screen wakes.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showingThis = _enabled && _isActiveTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Use as lock screen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  color: showingThis ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(showingThis ? Icons.lock : Icons.lock_open, color: showingThis ? scheme.onPrimaryContainer : null),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            showingThis
                                ? '"${widget.theme.name}" is your lock screen'
                                : _enabled
                                    ? 'Another theme is on your lock screen'
                                    : 'Custom lock screen is off',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Before you start', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                _PermissionTile(
                  done: _notificationsOk,
                  title: 'Allow notifications',
                  subtitle: 'Android requires a small "lock screen active" notification while the feature runs.',
                  onFix: LockOverlayBridge.requestNotificationPermission,
                ),
                _PermissionTile(
                  done: _overlayOk,
                  title: 'Allow "Display over other apps"',
                  subtitle: 'Lets LockForge show your design the instant the screen turns on.',
                  onFix: LockOverlayBridge.openOverlaySettings,
                ),
                const SizedBox(height: 20),
                if (!showingThis)
                  FilledButton.icon(
                    onPressed: _ready && !_busy ? _activate : null,
                    icon: const Icon(Icons.lock),
                    label: Text(_busy ? 'Setting up…' : 'Set "${widget.theme.name}" as lock screen'),
                  )
                else ...[
                  FilledButton.tonalIcon(
                    onPressed: LockOverlayBridge.showNow,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Show it now'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _push,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh weather, steps & calendar'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _turnOff, child: const Text('Turn off custom lock screen')),
                ],
                if (_status.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_status, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 28),
                Text('How it works', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(
                  '• Your design appears whenever the screen wakes. Swipe up on it to continue.\n'
                  '• Your PIN, pattern or fingerprint still protects the phone — this is a themed layer, not a replacement for security.\n'
                  '• Edits to this theme sync to the lock screen automatically. Weather, steps and calendar refresh when you open the app or tap Refresh.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final bool done;
  final String title;
  final String subtitle;
  final VoidCallback onFix;
  const _PermissionTile({required this.done, required this.title, required this.subtitle, required this.onFix});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? Colors.greenAccent : Theme.of(context).colorScheme.outline),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: done ? null : FilledButton.tonal(onPressed: onFix, child: const Text('Allow')),
    );
  }
}
