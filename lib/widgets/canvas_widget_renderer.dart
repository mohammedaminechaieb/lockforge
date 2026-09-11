import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lock_widget.dart';
import '../services/weather_service.dart';
import '../services/health_service.dart';
import '../services/calendar_service.dart';

class CanvasWidgetRenderer extends StatefulWidget {
  final LockWidgetConfig config;
  final bool liveData; // false in the editor (shows placeholder text, cheaper), true in preview

  const CanvasWidgetRenderer({super.key, required this.config, this.liveData = false});

  @override
  State<CanvasWidgetRenderer> createState() => _CanvasWidgetRendererState();
}

class _CanvasWidgetRendererState extends State<CanvasWidgetRenderer> {
  String _display = '--';
  Timer? _clockTimer;
  StreamSubscription<int>? _stepSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CanvasWidgetRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.type != widget.config.type || oldWidget.liveData != widget.liveData) {
      _teardown();
      _load();
    }
  }

  void _load() {
    switch (widget.config.type) {
      case LockWidgetType.clock:
        _updateClock();
        _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
        break;
      case LockWidgetType.text:
        setState(() => _display = widget.config.customText);
        break;
      case LockWidgetType.weather:
        setState(() => _display = widget.liveData ? 'Loading…' : '☀️ 21°C');
        if (widget.liveData) {
          WeatherService().fetchCurrent().then((reading) {
            if (!mounted) return;
            setState(() => _display = reading == null ? '--' : '${reading.condition} ${reading.tempCelsius.round()}°C');
          });
        }
        break;
      case LockWidgetType.steps:
        setState(() => _display = widget.liveData ? '…' : '4,231 steps');
        if (widget.liveData) {
          _stepSub = HealthService().stepCountStream().listen((steps) {
            if (!mounted) return;
            setState(() => _display = '$steps steps');
          }, onError: (_) {
            if (!mounted) return;
            setState(() => _display = '-- steps');
          });
        }
        break;
      case LockWidgetType.calendar:
        setState(() => _display = widget.liveData ? 'Loading…' : 'Team sync · 2:00 PM');
        if (widget.liveData) {
          CalendarService().fetchNextEvent().then((event) {
            if (!mounted) return;
            setState(() => _display = event == null
                ? 'No events today'
                : '${event.title} · ${TimeOfDay.fromDateTime(event.start).format(context)}');
          });
        }
        break;
    }
  }

  void _updateClock() {
    final now = DateTime.now();
    if (!mounted) return;
    final config = widget.config;
    String timePart;
    if (config.use24HourClock) {
      final h = now.hour.toString().padLeft(2, '0');
      final m = now.minute.toString().padLeft(2, '0');
      timePart = config.showSeconds ? '$h:$m:${now.second.toString().padLeft(2, '0')}' : '$h:$m';
    } else {
      final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
      final m = now.minute.toString().padLeft(2, '0');
      final suffix = now.hour >= 12 ? 'PM' : 'AM';
      timePart = config.showSeconds
          ? '$hour12:$m:${now.second.toString().padLeft(2, '0')} $suffix'
          : '$hour12:$m $suffix';
    }
    final datePart = config.showDateWithClock
        ? '\n${_weekdayName(now.weekday)}, ${_monthName(now.month)} ${now.day}'
        : '';
    setState(() => _display = '$timePart$datePart');
  }

  String _weekdayName(int weekday) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[weekday - 1];
  }

  String _monthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }

  void _teardown() {
    _clockTimer?.cancel();
    _stepSub?.cancel();
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return Text(
      _display,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: config.fontSize,
        color: config.color,
        fontFamily: config.fontFamily.isEmpty ? null : config.fontFamily,
        fontWeight: config.fontWeight,
      ),
    );
  }
}
