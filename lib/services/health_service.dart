import 'package:pedometer/pedometer.dart';

/// Wraps the pedometer plugin's step-count stream. This reads the device's
/// built-in step sensor directly — no health-platform account or API
/// linking required, unlike Google Fit/Apple Health integrations.
class HealthService {
  Stream<int> stepCountStream() {
    return Pedometer.stepCountStream.map((event) => event.steps);
  }
}
