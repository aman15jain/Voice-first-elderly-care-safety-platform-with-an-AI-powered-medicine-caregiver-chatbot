import 'package:elderly_care_app/features/activity/domain/daily_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DailyActivity.fromJson parses a full day row', () {
    final day = DailyActivity.fromJson({'date': '2026-01-01', 'medicineInteractions': 3, 'gameSessions': 1, 'active': true});
    expect(day.date, '2026-01-01');
    expect(day.medicineInteractions, 3);
    expect(day.gameSessions, 1);
    expect(day.active, isTrue);
  });

  test('DailyActivity.fromJson parses an inactive day', () {
    final day = DailyActivity.fromJson({'date': '2026-01-02', 'medicineInteractions': 0, 'gameSessions': 0, 'active': false});
    expect(day.active, isFalse);
  });
}
