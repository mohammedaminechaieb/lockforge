import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherReading {
  final double tempCelsius;
  final String condition;
  WeatherReading({required this.tempCelsius, required this.condition});
}

/// Open-Meteo (open-meteo.com) needs no API key and no account — good fit
/// for a side-project widget that shouldn't require the user to go
/// register for a weather API just to see the temperature on their canvas.
class WeatherService {
  Future<WeatherReading?> fetchCurrent() async {
    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition();
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${position.latitude}&longitude=${position.longitude}'
        '&current=temperature_2m,weather_code',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final current = data['current'];
      return WeatherReading(
        tempCelsius: (current['temperature_2m'] as num).toDouble(),
        condition: _describeCode(current['weather_code'] as int),
      );
    } catch (_) {
      return null; // widget renderer falls back to "--" on null
    }
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  String _describeCode(int code) {
    // Minimal mapping of Open-Meteo's WMO weather codes — expand as needed.
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Cloudy';
    if (code <= 48) return 'Fog';
    if (code <= 67) return 'Rain';
    if (code <= 77) return 'Snow';
    if (code <= 99) return 'Storm';
    return 'Unknown';
  }
}
