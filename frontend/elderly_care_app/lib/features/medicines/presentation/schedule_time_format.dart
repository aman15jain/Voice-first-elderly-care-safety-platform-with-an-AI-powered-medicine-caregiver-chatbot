import 'package:intl/intl.dart';

/// Schedules are stored as UTC "HH:mm" (see docs/architecture.md), so display converts them
/// back to the device's local time and uses the 12-hour clock.
String localTimeLabelFromUtc(String utcHhmm) {
  final parts = utcHhmm.split(':');
  final now = DateTime.now().toUtc();
  final utc = DateTime.utc(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  return DateFormat.jm().format(utc.toLocal());
}
