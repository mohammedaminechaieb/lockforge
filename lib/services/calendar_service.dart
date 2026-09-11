import 'package:device_calendar/device_calendar.dart';

class NextEvent {
  final String title;
  final DateTime start;
  NextEvent({required this.title, required this.start});
}

/// Reads the device's actual calendars (via device_calendar), not a
/// separate app-only event store — so it reflects whatever the user has
/// on their real calendar app.
class CalendarService {
  final _plugin = DeviceCalendarPlugin();

  Future<NextEvent?> fetchNextEvent() async {
    final permissionResult = await _plugin.hasPermissions();
    if (permissionResult.data != true) {
      final requestResult = await _plugin.requestPermissions();
      if (requestResult.data != true) return null;
    }

    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars = calendarsResult.data ?? [];
    if (calendars.isEmpty) return null;

    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    NextEvent? soonest;
    for (final calendar in calendars) {
      if (calendar.id == null) continue;
      final eventsResult = await _plugin.retrieveEvents(
        calendar.id,
        RetrieveEventsParams(startDate: now, endDate: endOfDay),
      );
      for (final event in eventsResult.data ?? <Event>[]) {
        final start = event.start;
        if (start == null) continue;
        if (soonest == null || start.isBefore(soonest.start)) {
          soonest = NextEvent(title: event.title ?? 'Untitled event', start: start);
        }
      }
    }
    return soonest;
  }
}
