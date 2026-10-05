import 'package:elderly_care_app/features/medicines/presentation/schedule_time_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stored UTC times are shown as 12-hour local time', () {
    for (final utc in ['00:00', '02:45', '15:45', '23:59']) {
      expect(localTimeLabelFromUtc(utc), matches(RegExp(r'^\d{1,2}:\d{2}\s(AM|PM)$')));
    }
  });
}
