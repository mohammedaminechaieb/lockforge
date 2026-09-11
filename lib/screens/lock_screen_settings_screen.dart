import 'package:flutter/material.dart';
import '../models/theme_pack.dart';
import '../services/lock_overlay_bridge.dart';
import '../services/home_widget_service.dart';
import '../services/weather_service.dart';
import '../services/calendar_service.dart';

/// Lets the user turn the real wake-screen overlay on/off and push the
/// currently-open design to it. Enabling it starts LockTriggerService
/// natively (see native_lockscreen_snippets/android/) — the screen also
/// re-pushes fresh live values (weather/steps/calendar) each time it
/// opens, since the native overlay has no way to fetch those on its own.
class LockScreenSettingsScreen extends StatefulWidget {
  final ThemePack theme;
  const LockScreenSettingsScreen({super.key, required this.theme});

  @override
  State<LockScreenSettingsScreen> createState() => _LockScreenSettingsScreenState();
}

class _LockScreenSettingsScreenState extends State<LockScreenSettingsScreen> {
  bool _enabled = false;
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await LockOverlayBridge.isEnabled();
    setState(() {
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    await LockOverlayBridge.setEnabled(value);
    if (value) await _pushCurrentDesign();
  }

  Future<void> _pushCurrentDesign() async {
    setState(() => _status = 'Pushing design…');

    final calendarEvent = await CalendarService().fetchNextEvent();
    final calendarLabel = calendarEvent == null
        ? 'No events today'
        : '${calendarEvent.title} \u00b7 ${TimeOfDay.fromDateTime(calendarEvent.start).format(context)}';

    final weather = await WeatherService().fetchCurrent();
    final weatherLabel = weather == null ? '--' : '${weather.condition} ${weather.tempCelsius.round()}\u00b0C';

    await HomeWidgetService.pushLockScreenState(
      theme: widget.theme,
      weatherLabel: weatherLabel,
      calendarLabel: calendarLabel,
    );

    setState(() => _status = 'Design pushed \u00b7 will show next time the screen wakes.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lock Screen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Shows your current design over the screen the instant it wakes — real wallpaper, your widgets on top. '
                    'If your device has a PIN, pattern, or biometric lock set, Android still requires that to actually unlock; '
                    'this is a themed layer at the wake moment, not a security bypass.',
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('Show on lock screen'),
                    value: _enabled,
                    onChanged: _toggle,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _enabled ? _pushCurrentDesign : null,
                    child: const Text('Push current design now'),
                  ),
                  const SizedBox(height: 12),
                  Text(_status, style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  const Text(
                    'Tip: swipe up on the overlay to dismiss it manually, same as a real lock screen gesture.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
    );
  }
}
